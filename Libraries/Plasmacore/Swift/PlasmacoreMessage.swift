#if os(OSX)
  import Cocoa
#endif

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
//   DATA_TYPE_REAL64  = 1   # value:Int64 (Real64.integer_bits stored)
//   DATA_TYPE_INT64   = 2   # high:Int32, low:Int32
//   DATA_TYPE_INT32   = 3   # value:Int32
//   DATA_TYPE_BYTE    = 4   # Byte[arg_data_size]

class PlasmacoreMessage
{
  struct DataType
  {
    static let REAL64  = 1
    static let INT64   = 2
    static let INT32   = 3
    static let BYTE    = 4
  }

  static var next_message_id = 1

  var type       : String
  var message_id : Int
  var timestamp  : Double

  var data          = [UInt8]()
  var string_buffer = [Character]()
  var entries  = [String:Int]()
  var position = 0

  var _reply:PlasmacoreMessage? = nil
  var _block_transmission = false

  convenience init( type:String )
  {
    self.init( type:type, message_id:PlasmacoreMessage.next_message_id )
    PlasmacoreMessage.next_message_id += 1
  }

  convenience init( data:[UInt8] )
  {
    self.init()
    self.data = data
    type = readString()
    message_id = readInt32()
    timestamp = readReal64()
    while (indexAnother()) {}
  }

  convenience init( type:String, message_id:Int )
  {
    self.init()
    self.type = type
    self.message_id = message_id
    writeString( type )
    writeInt32( message_id )
    writeReal64( timestamp )
  }

  convenience init( reply_to_message_id:Int )
  {
    self.init( type: "", message_id: reply_to_message_id )
  }

  init()
  {
    type = "Unspecified"
    message_id = 0
    timestamp = PlasmacoreMessage.currentTime()
  }

  func reply()->PlasmacoreMessage
  {
    if (_reply == nil)
    {
      _reply = PlasmacoreMessage( type:"", message_id:message_id )
      _reply!._block_transmission = true
    }
    return _reply!
  }

  func getBytes( name:String )->[UInt8]
  {
    if let offset = entries[ name ]
    {
      position = offset
      switch (readByte())
      {
        case DataType.BYTE:
          return readBytes()
        default:
          break
      }
    }
    return [UInt8]()
  }

  func getDictionary( name:String, default_value:String="" )->[String:AnyObject]?
  {
    let jsonString = getString(name: name, default_value: default_value)
    if let data = jsonString.data(using: String.Encoding.utf8) {
        do {
            return try JSONSerialization.jsonObject(with: data, options: []) as? [String:AnyObject]
        } catch let error as NSError {
            print(error)
        }
    }
    return nil

  }

  func getInt32( name:String, default_value:Int=0 )->Int
  {
    if let offset = entries[ name ]
    {
      position = offset
      let arg_type = readByte()
      let arg_size = readInt32()
      switch (arg_type)
      {
        case DataType.REAL64:
          return Int(readReal64())

        case DataType.INT64:
          return Int(readInt64())

        case DataType.INT32:
          return readInt32()

        case DataType.BYTE:
          if (arg_size == 0) { return 0 }
          return (readByte())

        default:
          return default_value
      }
    }
    return default_value

  }

  func getInt64( name:String, default_value:Int64=0 )->Int64
  {
    if let offset = entries[ name ]
    {
      position = offset
      let arg_type = readByte()
      let arg_size = readInt32()
      switch (arg_type)
      {
        case DataType.REAL64:
          return Int64(readReal64())

        case DataType.INT64:
          return readInt64()

        case DataType.INT32:
          return Int64(readInt32())

        case DataType.BYTE:
          if (arg_size == 0) { return 0 }
          return Int64( readByte() )

        default:
          return default_value
      }
    }
    return default_value

  }

  func getLogical( name:String, default_value:Bool=false )->Bool
  {
    return getInt32( name: name, default_value:(default_value ? 1 : 0) ) != 0
  }

  func getReal64( name:String, default_value:Double=0.0 )->Double
  {
    if let offset = entries[ name ]
    {
      position = offset
      let arg_type = readByte()
      let arg_size = readInt32()
      switch (arg_type)
      {
      case DataType.REAL64:
        return readReal64()

      case DataType.INT64:
        return Double(readInt64())

      case DataType.INT32:
        return Double(readInt32())

      case DataType.BYTE:
        if (arg_size == 0) { return 0 }
        return Double(readByte())

      default:
        return default_value
      }
    }
    return default_value

  }

  func getString( name:String, default_value:String="" )->String
  {
    if let offset = entries[ name ]
    {
      position = offset
      let arg_type = readByte()
      switch (arg_type)
      {
        case DataType.BYTE:
          return readString()
        default:
          return default_value
      }
    }
    return default_value
  }

  func indexAnother()->Bool
  {
    if (position == data.count) { return false }
    let name = readString()
    entries[ name ] = position

    readByte()  // skip over arg_type for now
    position += readInt32()
    return true
  }

  func post()
  {
    if (_block_transmission) { return }
    Plasmacore.singleton.post( self );
  }

  func post_rsvp( _ callback:@escaping ((PlasmacoreMessage)->Void) )
  {
    if (_block_transmission) { return }
    Plasmacore.singleton.post_rsvp( self, callback:callback );
  }

  @discardableResult
  func send()->PlasmacoreMessage?
  {
    if (_block_transmission) { return nil }

    Plasmacore.singleton.update()  // transmit any post()ed messages

    objc_sync_enter(Plasmacore.singleton); defer { objc_sync_exit(Plasmacore.singleton) }

    if let result_data = RogueInterface_send_message( data, Int32(data.count) )
    {
      return PlasmacoreMessage( data:[UInt8](result_data) )
    }
    else
    {
      return nil
    }
  }

  @discardableResult
  func set( name:String, value:[UInt8] )->PlasmacoreMessage
  {
    position = data.count
    writeString( name )
    entries[ name ] = position
    writeByte( DataType.BYTE )
    writeBytes( value )
    return self
  }

  @discardableResult
  func set( name:String, value:Int64 )->PlasmacoreMessage
  {
    position = data.count
    writeString( name )
    entries[ name ] = position
    writeTypeAndSize( DataType.INT64, size: 8 )
    writeInt32( Int(value>>32) )
    writeInt32( Int(value) )
    return self
  }

  @discardableResult
  func set( name:String, value:Int )->PlasmacoreMessage
  {
    position = data.count
    writeString( name )
    entries[ name ] = position
    writeTypeAndSize( DataType.INT32, size: 4 )
    writeInt32( value )
    return self
  }

  @discardableResult
  func set( name:String, value:Bool )->PlasmacoreMessage
  {
    position = data.count
    writeString( name )
    entries[ name ] = position
    writeTypeAndSize( DataType.BYTE, size: 1 )
    writeByte( value ? 1 : 0 )
    return self
  }

  @discardableResult
  func set( name:String, value:Double )->PlasmacoreMessage
  {
    position = data.count
    writeString( name )
    entries[ name ] = position
    writeTypeAndSize( DataType.REAL64, size: 8 )
    writeReal64( value )
    return self
  }

  @discardableResult
  func set( name:String, value:String )->PlasmacoreMessage
  {
    position = data.count
    writeString( name )
    entries[ name ] = position
    writeByte( DataType.BYTE )  // type
    writeString( value )
    return self
  }

  //---------------------------------------------------------------------------
  // PRIVATE
  //---------------------------------------------------------------------------

  @discardableResult
  fileprivate func readByte()->Int
  {
    if (position >= data.count) { return 0 }
    position += 1
    return Int(data[position-1])
  }

  fileprivate func readBytes()->[UInt8]
  {
    let count = readInt32()
    var buffer = [UInt8]()
    buffer.reserveCapacity( count )
    for _ in 1...count
    {
      buffer.append( UInt8(readByte()) )
    }
    return buffer
  }

  fileprivate func readInt32()->Int
  {
    var result = readByte()
    result = (result << 8) | readByte()
    result = (result << 8) | readByte()
    return (result << 8) | readByte()
  }

  fileprivate func readInt64()->Int64
  {
    var n = UInt64( readInt32() ) << 32
    n = n | UInt64( UInt32(readInt32()) )
    return Int64(n)
  }

  fileprivate func readReal64()->Double
  {
    var n = UInt64( readInt32() ) << 32
    n = n | UInt64( UInt32(readInt32()) )
    return Double(bitPattern:n)
  }

  fileprivate func readString()->String
  {
    let bytes = readBytes()
    if let string = String( bytes:bytes, encoding:.utf8 )
    {
      return string
    }
    else
    {
      return ""
    }
  }

  fileprivate static func currentTime()->Double
  {
    var darwin_time : timeval = timeval( tv_sec:0, tv_usec:0 )
    gettimeofday( &darwin_time, nil )
    return (Double(darwin_time.tv_sec)) + (Double(darwin_time.tv_usec) / 1000000)
  }

  fileprivate func writeTypeAndSize( _ type:Int, size:Int )
  {
    writeByte( type )
    writeInt32( size )
  }

  fileprivate func writeByte( _ value:Int )
  {
    position += 1
    if (position > data.count)
    {
      data.append( UInt8(value&255) )
    }
    else
    {
      data[ position-1 ] = UInt8( value )
    }
  }

  fileprivate func writeBytes( _ bytes:[UInt8] )
  {
    writeInt32( bytes.count )
    for byte in bytes
    {
      writeByte( Int(byte) )
    }
  }

  fileprivate func writeInt32( _ value:Int )
  {
    writeByte( value >> 24 )
    writeByte( value >> 16 )
    writeByte( value >> 8  )
    writeByte( value )
  }

  fileprivate func writeReal64( _ value:Double )
  {
    let bits = value.bitPattern
    writeInt32( Int((bits>>32)&0xFFFFffff) )
    writeInt32( Int(bits&0xFFFFffff) )
  }

  fileprivate func writeString( _ value:String )
  {
    writeBytes( Array(value.utf8) )
  }
}

