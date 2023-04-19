//
//  File.swift
//  
//
//  Created by macmini on 2023/4/14.
//

import Foundation

public typealias Byte = UInt8
public typealias ByteArray = [UInt8]

public protocol IPDU {
    
}

public protocol ISDU {
    
}

public enum BundleType : String {
    case request, response, timeout, exception, biz_fail
}

public struct Bundle {
    //当 type = request 时，为请求数据
    //当 type = response 时，为成功的响应数据
    //当 type = timeout 时，为请求数据
    //当 type = exception 时，为请求数据，设计用于发送失败
    //当 type = biz_fail 时，为失败的响应数据，
    let sdu: ISDU
    let type: BundleType
    
    init(sdu: ISDU, type: BundleType) {
        self.sdu = sdu
        self.type = type
    }
}

////可能可以移除
//public protocol ISDUManager {
//
//}
//
////可能移除
//public protocol ISduWriter {
//    func write(sdu: any ISDU)
//}
//
////可能移除
//public protocol ISduReceiver {
//
//}

public protocol ISduAnalyzer {
    func analyze(data:ByteArray) -> any Collection<ISDU>
}




