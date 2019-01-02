#include "Plasmacore.h"
#include "RogueInterface.h"
#include "RogueProgram.h"
#include "unistd.h"


#define ROGUEAPI

static int          RogueInterface_argc = 0;
static const char** RogueInterface_argv = {0};


ROGUEAPI extern "C" RogueString* Plasmacore_get_user_data_folder()
{
#ifdef LOCAL_FS
  return RogueString_validate(RogueString_create_from_utf8(LOCAL_FS));
#else
  return RogueString_validate(RogueString_create_from_utf8("."));
#endif
}

ROGUEAPI extern "C" RogueString* Plasmacore_get_application_data_folder()
{
  return RogueString_validate(RogueString_create_from_utf8("."));
}

extern "C" RogueString* Plasmacore_find_asset( RogueString* filepath )
{
  if (access((char *)filepath->utf8, R_OK) == -1) return 0;
  return RogueString_create_from_utf8((char *)filepath->utf8);
}

//-----------------------------------------------------------------------------
// Message
//-----------------------------------------------------------------------------
bool PlasmacoreMessage_send( RogueByte_List* bytes )
{
  Buffer data;
  data.add( bytes->data->as_bytes, bytes->count );
  PlasmacoreMessage m( data );
  Plasmacore::singleton.dispatch( m );
  if (m._reply)
  {
    m._reply->sent = true;
    RogueInt32 count = (RogueInt32) m._reply->data.count;
    RogueByte_List__clear( bytes );
    RogueByte_List__reserve__Int32( bytes, count );
    bytes->count = count;
    memcpy( bytes->data->as_bytes, &m._reply->data[0], count );
    return true;
  }
  else
  {
    return false;
  }
}


ROGUEAPI void RogueInterface_configure()
{
  Rogue_configure( RogueInterface_argc, RogueInterface_argv );
  PlasmacoreSoundInit();
}

ROGUEAPI void RogueInterface_launch()
{
  Rogue_launch();
}

ROGUEAPI void RogueInterface_post_messages( PlasmacoreList<uint8_t>& io )
{
  try
  {
    Rogue_collect_garbage();

    RogueClassPlasmacore__MessageManager* mm =
      (RogueClassPlasmacore__MessageManager*) ROGUE_SINGLETON(Plasmacore__MessageManager);
    RogueByte_List* list = mm->io_buffer;

    RogueByte_List__clear( list );
    RogueByte_List__reserve__Int32( list, io.count );
    memcpy( list->data->as_bytes, io.data, io.count );
    list->count = io.count;
    io.clear();

    // Call Rogue MessageManager.update(), which sends back a reference to another byte
    // list containing messages to us.
    list = RoguePlasmacore__MessageManager__update( mm );

    if ( !list ) return;
    io.add( list->data->as_bytes, list->count );
  }
  catch (RogueException* err)
  {
    RogueException__display( err );
    return;
  }
}

ROGUEAPI PlasmacoreMessage* RogueInterface_send_message( PlasmacoreMessage& m )
{
  RogueInt32 count = (RogueInt32) m.data.count;
  RogueClassPlasmacore__MessageManager* mm =
    (RogueClassPlasmacore__MessageManager*) ROGUE_SINGLETON(Plasmacore__MessageManager);
  RogueByte_List* list = mm->direct_message_buffer;
  RogueByte_List__clear( list );
  RogueByte_List__reserve__Int32( list, count );
  memcpy( list->data->as_bytes, &m.data[0], count );
  list->count = count;

  if (RoguePlasmacore__MessageManager__receive_message(mm))
  {
    // direct_message_buffer has been filled with result bytes
    Buffer reply_data;
    reply_data.add( list->data->as_bytes, list->count );
    if (m._reply) delete m._reply;
    m._reply = new PlasmacoreMessage( reply_data );
    return m._reply;
  }
  else
  {
    return NULL;
  }
}

ROGUEAPI void RogueInterface_set_arg_count( int count )
{
  // Note that this will leak the old argv if app is reconfigured
  RogueInterface_argc = count;
  RogueInterface_argv = new const char*[ count+1 ];
  memset( RogueInterface_argv, 0, sizeof(const char*) * (count+1) );
}

ROGUEAPI void RogueInterface_set_arg_value( int index, const char* value )
{
  size_t len = strlen( value );
  char* copy = new char[ len+1 ];
  strcpy( copy, value );
  RogueInterface_argv[ index ] = copy;
}
