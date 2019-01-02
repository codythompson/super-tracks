#include "PlasmacoreMessage.h"
#include "RogueInterface.h"

#include <cstdio>
#include "Plasmacore.h"

MID PlasmacoreMessage::next_message_id = 1;

PlasmacoreMessage::PlasmacoreMessage ( Buffer& data )
{
  //init();
  this->data = data;
  readString( type );
  message_id = readInt32();
  timestamp = readReal64();
  while (indexAnother());
}

PlasmacoreMessage::PlasmacoreMessage (const char * type, MID message_id )
{
  //init();
  this->type = type;
  this->message_id = message_id;
  this->timestamp = Plasmacore_time();
  writeString( type );
  writeInt32( message_id );
  writeReal64( timestamp );
}

PlasmacoreMessage::PlasmacoreMessage (const char * type )
    : PlasmacoreMessage(type, PlasmacoreMessage::next_message_id++)
{
}

PlasmacoreMessage::~PlasmacoreMessage()
{
  if (_reply)
  {
    delete _reply;
    _reply = NULL;
  }
}

PlasmacoreMessage* PlasmacoreMessage::reply()
{
  if ( !_reply ) _reply = new PlasmacoreMessage( "", message_id );
  return _reply;
}

int32_t PlasmacoreMessage::getInt32 (const char* name, int32_t default_value)
{
  auto entry = entries.find( name );
  if (entry)
  {
    position = entry->value;
    auto arg_type = readByte();
    auto arg_size = readInt32();
    if (arg_size == 0) return default_value;

    switch (arg_type)
    {
      case DataType::REAL64:
        return (int32_t)readReal64();

      case DataType::INT64:
        return (int32_t)readInt64();

      case DataType::INT32:
        return readInt32();

      case DataType::BYTE:
        return readByte();
    }
  }
  return default_value;
}

int64_t PlasmacoreMessage::getInt64 (const char* name, int64_t default_value)
{
  auto entry = entries.find( name );
  if (entry)
  {
    position = entry->value;
    auto arg_type = readByte();
    auto arg_size = readInt32();
    if (arg_size == 0) return default_value;

    switch (arg_type)
    {
      case DataType::REAL64:
        return (int64_t)readReal64();

      case DataType::INT64:
        return readInt64();

      case DataType::INT32:
        return (int64_t)readInt32();

      case DataType::BYTE:
        return readByte();
    }
  }
  return default_value;
}

bool PlasmacoreMessage::getLogical( const char* name, bool default_value )
{
  return getInt32( name, default_value ? 1 : 0 ) != 0;
}

double PlasmacoreMessage::getReal64( const char* name, double default_value )
{
  auto entry = entries.find( name );
  if (entry)
  {
    position = entry->value;
    auto arg_type = readByte();
    auto arg_size = readInt32();
    if (arg_size == 0) return default_value;

    switch (arg_type)
    {
      case DataType::REAL64:
        return readReal64();

      case DataType::INT64:
        return double(readInt64());

      case DataType::INT32:
        return double(readInt32());

      case DataType::BYTE:
        return double(readByte());
    }
  }
  return default_value;

}

void PlasmacoreMessage::getString( const char* name, PlasmacoreCString& result )
{
  auto entry = entries.find( name );
  if (entry)
  {
    position = entry->value;
    auto arg_type = readByte();
    auto arg_size = readInt32();
    if (arg_size == 0) return;

    if (arg_type == DataType::BYTE)
    {
      readString( result );
      return;
    }

    char buffer[ 80 ];
    switch (arg_type)
    {
      case DataType::REAL64:
        snprintf( buffer, 80, "%lf", readReal64() );
        return;

      case DataType::INT64:
        snprintf( buffer, 80, "%lld", (long long int)readInt64() );

      case DataType::INT32:
        snprintf( buffer, 80, "%d", readInt32() );
    }

    result = buffer;
  }
}

bool PlasmacoreMessage::indexAnother (void)
{
  if (position == data.count) { return false; }

  PlasmacoreCStringBuilder name;
  readString( name );
  entries[ name.as_c_string() ] = position;

  readByte();  // arg type
  auto arg_size = readInt32();
  position += arg_size;

  return true;
}

void PlasmacoreMessage::post()
{
  Plasmacore::singleton.post( *this );
  sent = true;
}

void PlasmacoreMessage::post_rsvp( HandlerCallback callback )
{
  Plasmacore::singleton.post_rsvp( *this, callback );
  sent = true;
}

PlasmacoreMessage* PlasmacoreMessage::send()
{
  Plasmacore::singleton.real_update( false );  // flush buffered post() messages.
  PlasmacoreMessage* result = RogueInterface_send_message( *this );
  sent = true;
  return result;
}

PlasmacoreMessage & PlasmacoreMessage::set( const char * name, Buffer & value )
{
  position = data.count;
  writeString( name );
  entries[ name ] = position;
  writeByte( DataType::BYTE );
  writeInt32( value.count );
  for (int i = 0; i < value.count; ++i)
  {
    writeByte( value[i] );
  }
  return *this;
}

PlasmacoreMessage & PlasmacoreMessage::set( const char * name, int64_t value )
{
  position = data.count;
  writeString( name );
  entries[ name ] = position;
  writeByte( DataType::INT64 );
  writeInt32( 8 );
  writeInt64( value );
  return *this;
}

PlasmacoreMessage & PlasmacoreMessage::set( const char * name, Int value )
{
  position = data.count;
  writeString( name );
  entries[ name ] = position;
  writeByte( DataType::INT32 );
  writeInt32( 4 );
  writeInt32( value );
  return *this;
}

PlasmacoreMessage & PlasmacoreMessage::set( const char * name, bool value )
{
  position = data.count;
  writeString( name );
  entries[ name ] = position;
  writeByte( DataType::BYTE );
  writeInt32( 1 );
  writeByte( value ? 1 : 0 );
  return *this;
}

PlasmacoreMessage & PlasmacoreMessage::set( const char * name, double value )
{
  position = data.count;
  writeString( name );
  entries[ name ] = position;
  writeByte( DataType::REAL64 );
  writeInt32( 8 );
  writeReal64( value );
  return *this;
}

PlasmacoreMessage & PlasmacoreMessage::set( const char * name, const char * value )
{
  position = data.count;
  writeString( name );
  entries[ name ] = position;
  writeByte( DataType::BYTE );
  writeString( value );
  return *this;
}


//---------------------------------------------------------------------------
// PRIVATE
//---------------------------------------------------------------------------

Int PlasmacoreMessage::readByte (void)
{
  if (position >= data.count) { return 0; }
  position += 1;
  return Int(data[position-1]);
}

int64_t PlasmacoreMessage::readInt64 (void)
{
  auto result = int64_t( readInt32() ) << 32;
  return result | int64_t( uint32_t(readInt32()) );
}

int32_t PlasmacoreMessage::readInt32()
{
  auto result = readByte();
  result = (result << 8) | readByte();
  result = (result << 8) | readByte();
  return (result << 8) | readByte();
}

double PlasmacoreMessage::readReal64 (void)
{
  auto n = uint64_t( readInt32() ) << 32;
  n = n | uint64_t( uint32_t(readInt32()) );
  return *((double*)&n);
}

void PlasmacoreMessage::readString ( PlasmacoreCString& result )
{
  PlasmacoreCStringBuilder string_buffer;
  auto count = readInt32();
  for (int i = 0; i < count; ++i)
  {
    string_buffer.add( char(readByte()) );
  }
  result = string_buffer.as_c_string();
}

void PlasmacoreMessage::readString ( PlasmacoreCStringBuilder& result )
{
  result.clear();
  auto count = readInt32();
  for (int i = 0; i < count; ++i)
  {
    result.add( char(readByte()) );
  }
}

void PlasmacoreMessage::writeByte ( Int value )
{
  position += 1;
  if (position > data.count)
  {
    data.add( uint8_t(value&255) );
  }
  else
  {
    data[ position-1 ] = uint8_t( value );
  }
}

void PlasmacoreMessage::writeInt32( Int value )
{
  writeByte( value >> 24 );
  writeByte( value >> 16 );
  writeByte( value >> 8  );
  writeByte( value );
}

void PlasmacoreMessage::writeInt64( int64_t value )
{
  writeInt32( Int(value>>32) );
  writeInt32( Int(value) );
}

void PlasmacoreMessage::writeReal64 ( double value )
{
  uint64_t bits = *(uint64_t*)(&value);
  writeInt32( Int((bits>>32)&0xFFFFffff) );
  writeInt32( Int(bits&0xFFFFffff) );
}

void PlasmacoreMessage::writeString ( const char* value )
{
  int len = strlen( value );
  writeInt32( len );
  for (int i = 0; i < len; ++i)
  {
    writeByte( value[i] );
  }
}
