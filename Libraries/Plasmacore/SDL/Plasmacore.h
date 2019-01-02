#ifndef PLASMACORE_H
#define PLASMACORE_H

#include <cstdint>

#include "PlasmacoreMessage.h"
#include "PlasmacoreUtility.h"

typedef int HID;
typedef int RID;
typedef int Int;
typedef PlasmacoreList<uint8_t> Buffer;

//=============================================================================
//  PlasmacoreLauncher
//=============================================================================
struct PlasmacoreLauncher
{
  // PROPERTIES
  int               argc;
  char**            argv;
  PlasmacoreCString default_window_title;
  int               default_display_width;
  int               default_display_height;

  // METHODS
  PlasmacoreLauncher( int argc, char* argv[] );
  PlasmacoreLauncher( int argc, char* argv[], PlasmacoreCString default_window_title, int default_display_width, int default_display_height );

  int launch();
};


class PlasmacoreMessageHandler
{
public:
  const char* type;
  HandlerCallback callback;

  PlasmacoreMessageHandler (const char* type, HandlerCallback callback)
  : type(type), callback(callback)
  {
  }

  PlasmacoreMessageHandler ()
  : type("<invalid>")
  {
  }
};



class Plasmacore
{
public:
  static Plasmacore singleton;

  bool is_configured = false;
  bool is_launched   = false;

  double idleUpdateFrequency = 0.5;

  Buffer pending_message_data;
  Buffer io_buffer;
  Buffer decode_buffer;

  bool is_sending = false;
  bool update_requested = false;

  PlasmacoreStringTable<PlasmacoreMessageHandler*> handlers;
  PlasmacoreIntTable<PlasmacoreMessageHandler*>    reply_handlers;
  PlasmacoreIntTable<void*> resources;

  bool update_timer = false; // true if running

  void set_message_handler( const char * type, HandlerCallback handler );
  Plasmacore & configure();
  RID getResourceID( void * resource);
  Plasmacore & launch();
  Plasmacore & relaunch();
  void remove_message_handler( const char* type );
  void post( PlasmacoreMessage & m );
  void post_rsvp( PlasmacoreMessage & m, HandlerCallback callback );
  Plasmacore & setIdleUpdateFrequency( double f );
  void start();
  void stop();
  static void update(void * dummy);
  static void fast_update(void * dummy);
  void real_update(bool reschedule);
  void dispatch( PlasmacoreMessage& m );
};

#endif
