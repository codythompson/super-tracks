#if os(OSX)
import Cocoa
#else
import Foundation
#endif

@objc class PlasmacoreInterface : NSObject
{
  @objc class func dispatch( _ data:UnsafePointer<UInt8>, count:Int )->NSData?
  {
    let m = PlasmacoreMessage( data:Array(UnsafeBufferPointer(start:data,count:count)) )
    Plasmacore.singleton.dispatch( m )
    if let reply = m._reply
    {
      reply._block_transmission = false
      return NSData( bytes:reply.data, length:reply.data.count )
    }
    else
    {
      return nil
    }
  }
}


class Plasmacore
{
  static let _singleton = Plasmacore()

  static var singleton:Plasmacore
  {
    get
    {
      let result = _singleton
      if (result.is_launched) { return result }
      return result.configure().launch()
    }
  }

  class func start()
  {
    singleton.instanceStart( report:true )
  }

  class func stop()
  {
    singleton.instanceStop( report:true )
  }

  class func save()
  {
    PlasmacoreMessage( type:"Application.on_save" ).send()
  }

  class func setMessageListener( type:String, listener:@escaping ((PlasmacoreMessage)->Void) )
  {
    _singleton.instanceSetMessageListener( type: type, once:false, listener: listener )
  }

  class func setMessageListener( type:String, once:Bool, listener:@escaping ((PlasmacoreMessage)->Void) )
  {
    _singleton.instanceSetMessageListener( type: type, once:once, listener: listener )
  }

  class func removeMessageListener( type:String )
  {
    _singleton.instanceRemoveMessageListener( type:type )
  }

  var is_configured = false
  var is_launched   = false

  var idleUpdateFrequency = 0.5

  var pending_message_data = [UInt8]()
  var io_buffer = [UInt8]()

  var is_sending = false

  var listeners       = [String:PlasmacoreMessageListener]()
  var reply_listeners = [Int:PlasmacoreMessageListener]()
  var resources = [Int:AnyObject]()
  var next_resource_id = 1

  var update_timer : Timer?

  fileprivate init()
  {
  }

  func instanceSetMessageListener( type:String, listener:@escaping ((PlasmacoreMessage)->Void) )
  {
    instanceSetMessageListener( type:type, once:false, listener:listener )
  }

  func instanceSetMessageListener( type:String, once:Bool, listener:@escaping ((PlasmacoreMessage)->Void) )
  {
    objc_sync_enter( self ); defer { objc_sync_exit(self) }   // @synchronized (self)

    listeners[ type ] = PlasmacoreMessageListener( type:type, once:once, callback:listener )
  }

  @discardableResult
  func configure()->Plasmacore
  {
    if (is_configured) { return self }
    is_configured = true

    instanceSetMessageListener( type: "", listener:
      {
        (m:PlasmacoreMessage) in
          if let info = Plasmacore.singleton.reply_listeners.removeValue( forKey: m.message_id )
          {
            info.callback( m )
          }
      }
    )

    #if os(OSX)
    instanceSetMessageListener( type:"Window.create", listener:
      {
        (m:PlasmacoreMessage) in
        let name = m.getString( name:"name" )
        var className = name
        if let bundleID = Bundle.main.bundleIdentifier
        {
          if let dotIndex = Plasmacore.lastIndexOf( bundleID, lookFor:"." )
          {
            className = "\(bundleID[bundleID.index(bundleID.startIndex,offsetBy:dotIndex+1)...]).\(name)"
          }
        }

        let controller : NSWindowController
        if let controllerType = NSClassFromString( className ) as? NSWindowController.Type
        {
          NSLog( "Found controller \(className)" )
          controller = controllerType.init( windowNibName:NSNib.Name(rawValue: name) )
        }
        else if let controllerType = NSClassFromString( name ) as? NSWindowController.Type
        {
          NSLog( "Found controller \(name)" )
          controller = controllerType.init( windowNibName:NSNib.Name(rawValue: name) )
        }
        else
        {
          NSLog( "===============================================================================" )
          NSLog( "ERROR" )
          NSLog( "  No class found named \(name) or \(className)." )
          NSLog( "===============================================================================" )
          controller = NSWindowController( windowNibName:NSNib.Name(rawValue: name) )
        }

        Plasmacore.singleton.resources[ m.getInt32(name:"id") ] = controller
        NSLog( "Controller window:\(String(describing:controller.window))" )
      }
    )

    instanceSetMessageListener( type:"Window.show", listener:
      {
        (m:PlasmacoreMessage) in
          let window_id = m.getInt32( name:"id" )
          if let window = Plasmacore.singleton.resources[ window_id ] as? NSWindowController
          {
            window.showWindow( self )
          }
      }
    )
    #endif // os(OSX)

    RogueInterface_set_arg_count( Int32(CommandLine.arguments.count) )
    for (index,arg) in CommandLine.arguments.enumerated()
    {
      RogueInterface_set_arg_value( Int32(index), arg )
    }

    RogueInterface_configure();
    return self
  }

  func addResource( resource:AnyObject? )->Int
  {
    let result = next_resource_id
    next_resource_id += 1
    resources[ result ] = resource
    return result
  }

  func getResourceID( _ resource:AnyObject? )->Int
  {
    guard let resource = resource else { return 0 }

    for (key,value) in resources
    {
      if (value === resource) { return key }
    }
    return 0
  }

  @discardableResult
  func removeResource( id:Int )->AnyObject?
  {
    return resources[ id ]
  }

  @discardableResult
  func launch()->Plasmacore
  {
    if (is_launched) { return self }
    is_launched = true

    RogueInterface_launch()
    let m = PlasmacoreMessage( type:"Application.on_launch" )
#if os(OSX)
  m.set( name:"is_window_based", value:true )
#endif
    m.post()
    return self
  }

  static func lastIndexOf( _ st:String, lookFor:String )->Int?
  {
    if let r = st.range( of: lookFor, options:.backwards )
    {
      return st.distance(from: st.startIndex, to: r.lowerBound)
    }

    return nil
  }

  func relaunch()->Plasmacore
  {
    PlasmacoreMessage( type:"Application.on_launch" ).set( name:"is_window_based", value:true ).post()
    return self
  }

  func instanceRemoveMessageListener( type:String )
  {
    objc_sync_enter( self ); defer { objc_sync_exit(self) }   // @synchronized (self)
    listeners.removeValue( forKey:type )
  }

  func post( _ m:PlasmacoreMessage )
  {
    objc_sync_enter( self ); defer { objc_sync_exit(self) }    // @synchronized (self)

    let size = m.data.count
    pending_message_data.append( UInt8((size>>24)&255) )
    pending_message_data.append( UInt8((size>>16)&255) )
    pending_message_data.append( UInt8((size>>8)&255) )
    pending_message_data.append( UInt8(size&255) )
    for b in m.data
    {
      pending_message_data.append( b )
    }
    update()
  }

  func post_rsvp( _ m:PlasmacoreMessage, callback:@escaping ((PlasmacoreMessage)->Void) )
  {
    objc_sync_enter( self ); defer { objc_sync_exit(self) }   // @synchronized (self)
    reply_listeners[ m.message_id ] = PlasmacoreMessageListener( type:"", once:true, callback:callback )
    post( m )
  }

  func setIdleUpdateFrequency( _ f:Double )->Plasmacore
  {
    idleUpdateFrequency = f
    if (update_timer != nil)
    {
      instanceStop( report:false )
      instanceStart( report:false )
    }
    return self
  }

  func instanceStart( report:Bool )
  {
    if ( !is_launched ) { configure().launch() }

    if (update_timer === nil)
    {
      if (report) { PlasmacoreMessage( type:"Application.on_start" ).post() }
      update_timer = Timer.scheduledTimer( timeInterval: idleUpdateFrequency, target:self, selector: #selector(Plasmacore.update), userInfo:nil, repeats: true )
    }
    update()
  }

  func instanceStop( report:Bool )
  {
    if (update_timer !== nil)
    {
      if (report) { PlasmacoreMessage( type:"Application.on_stop" ).send() }
      update_timer!.invalidate()
      update_timer = nil
    }
  }

  func dispatch( _ m:PlasmacoreMessage )
  {
    objc_sync_enter( self ); defer { objc_sync_exit(self) }   // @synchronized (self)

    if let listener = listeners[ m.type ]
    {
      listener.callback( m )
      if (listener.once) { listeners.removeValue( forKey:listener.type ) }
    }
  }

  @objc func update()
  {
    objc_sync_enter( self ); defer { objc_sync_exit(self) }   // @synchronized (self)

    if (is_sending) { return }
    is_sending = true

    // Swap pending data with io_buffer data
    let temp = io_buffer
    io_buffer = pending_message_data
    pending_message_data = temp

    let received_data = RogueInterface_post_messages( io_buffer, Int32(io_buffer.count) )
    let count = received_data!.count
    received_data!.withUnsafeBytes
    { (bytes:UnsafePointer<UInt8>)->Void in
      //Use `bytes` inside this closure
      //...

      var read_pos = 0
      while (read_pos+4 <= count)
      {
        var size = Int( bytes[read_pos] ) << 24
        size |= Int( bytes[read_pos+1] ) << 16
        size |= Int( bytes[read_pos+2] ) << 8
        size |= Int( bytes[read_pos+3] )
        read_pos += 4;

        if (read_pos + size <= count)
        {
          var message_data = [UInt8]()
          message_data.reserveCapacity( size )
          for i in 0..<size
          {
            message_data.append( bytes[read_pos+i] )
          }

          let m = PlasmacoreMessage( data:message_data )
          dispatch( m )
          if let reply = m._reply
          {
            reply._block_transmission = false
            reply.post()
          }
        }
        else
        {
          NSLog( "*** Skipping message due to invalid size." )
        }
        read_pos += size
      }
    }

    io_buffer.removeAll()
    is_sending = false
  }
}

class PlasmacoreMessageListener
{
  var type      : String
  let once      : Bool
  var callback  : ((PlasmacoreMessage)->Void)

  init( type:String, once:Bool, callback:@escaping ((PlasmacoreMessage)->Void) )
  {
    self.type = type
    self.once = once
    self.callback = callback
  }
}

