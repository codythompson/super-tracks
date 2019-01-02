#ifndef PLASMACOREMESSAGE_H
#define PLASMACOREMESSAGE_H
//==============================================================================
// PlasmacoreMessage.h
//
// Communication mechanism between Plasmacore and Native Layer.
//
// post()ing a message adds it to a queue that is sent en mass during the next
// update or before a send().
//
// send()ing a message pushes the message queue and then sends the current
// message directly. It allows for a message in response.
//
// High-low byte order for Int32, Int64, and Real64
//
// Message Queue
//   while (has_another)
//     message_size : Int32              # number of bytes that follow not including this
//     message      : Byte[message_size]
//   endWhile
//
// Message
//   type_name_count : Int32                 # 0 means a reply
//   type_name_utf8  : UTF8[type_name_count]
//   message_id      : Int32                 # serial number (always present, only needed with RSVP replies)
//   timestamp       : Real64
//   while (position < message_size)
//     arg_name_count : Int32
//     arg_name       : UTF8[arg_name_count]
//     arg_data_type  : Byte
//     arg_data_size  : Int32
//     arg_data       : Byte[arg_data_size]
//   endWhile
//
// Data Types
//   DATA_TYPE_REAL64 = 1   # value:Int64 (Real64.integer_bits stored)
//   DATA_TYPE_INT64  = 2   # high:Int32, low:Int32
//   DATA_TYPE_INT32  = 3   # value:Int32
//   DATA_TYPE_BYTE   = 4   # value:Byte
//
//==============================================================================

#include <cstdint>

#include "PlasmacoreUtility.h"

class PlasmacoreMessage;

typedef void (*HandlerCallback)(PlasmacoreMessage*);


typedef int MID;
typedef int Int;
typedef PlasmacoreList<uint8_t> Buffer;


class PlasmacoreMessage
{
public:
  enum DataType
  {
    REAL64  = 1,
    INT64   = 2,
    INT32   = 3,
    BYTE    = 4,
  };

  static MID next_message_id;

  PlasmacoreCString type;
  MID    message_id;
  double timestamp;
  Buffer data;
  PlasmacoreStringTable<int> entries;
  int  position = 0;
  bool sent = false;
  PlasmacoreMessage* _reply = NULL;

  PlasmacoreMessage ( Buffer& data );
  PlasmacoreMessage ( const char * type, MID message_id );
  PlasmacoreMessage ( const char * type );
  ~PlasmacoreMessage();
  PlasmacoreMessage* reply();
  int32_t getInt32 (const char* name, int32_t default_value = 0);
  int64_t getInt64 (const char* name, int64_t default_value = 0 );
  bool getLogical( const char* name, bool default_value = false );
  double getReal64( const char* name, double default_value=0.0 );
  void getString( const char* name, PlasmacoreCString& result );
  bool indexAnother (void);
  void post();
  void post_rsvp( HandlerCallback callback );
  PlasmacoreMessage* send();
  PlasmacoreMessage & set( const char * name, Buffer & value );
  PlasmacoreMessage & set( const char * name, int64_t value );
  PlasmacoreMessage & set( const char * name, Int value );
  PlasmacoreMessage & set( const char * name, bool value );
  PlasmacoreMessage & set( const char * name, double value );
  PlasmacoreMessage & set( const char * name, const char * value );

private:
  //---------------------------------------------------------------------------
  // PRIVATE
  //---------------------------------------------------------------------------

  Int readByte (void);
  int64_t readInt64 (void);
  int32_t readInt32();
  double  readReal64 (void);
  void    readString ( PlasmacoreCString& result );
  void    readString ( PlasmacoreCStringBuilder& result );
  void    writeByte ( Int value );
  void    writeInt32( Int value );
  void    writeInt64( int64_t value );
  void    writeReal64 ( double value );
  void    writeString ( const char* value );
};

#endif
