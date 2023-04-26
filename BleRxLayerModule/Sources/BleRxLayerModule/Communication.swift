//
//  File.swift
//
//
//  Created by macmini on 2023/4/14.
//

import Foundation

public typealias Byte = UInt8
public typealias ByteArray = [UInt8]

/// 协议数据单元
/// ```
/// // a demo implement
/// struct PDU: IPDU, Equatable {
///    let cmd: Byte
///    let dataSize: Byte
///
///    let content: ByteArray
///
///    init(cmd: Byte, data: ByteArray) {
///        self.cmd = cmd
///        self.dataSize = Byte(data.count)
///        self.content = data
///    }
/// }
/// ```
public protocol IPDU: Equatable {
    var cmd: Byte { get }
    var content: ByteArray { get }
}

/// 服务数据单元
/// ```
/// // a demo implement
/// struct SDU: ISDU, Equatable {
///     static func == (lhs: SDU, rhs: SDU) -> Bool {
///        return lhs.sync == rhs.sync
///        && lhs.dst == rhs.dst
///        && lhs.content == rhs.content
///     }
///
///     let sync: Byte
///     let dst: Byte
///     var pdu: any IPDU
///
///     var content: ByteArray {
///         var tmp = ByteArray()
///         tmp.append(sync)
///         tmp.append(dst)
///         tmp.append(pdu.cmd)
///         tmp.append(contentsOf: pdu.content)
///         tmp.append(checksum())
///         return tmp
///     }
///
///     func checksum() -> Byte {
///         var sum: Byte = 0
///         sum+=sync
///         sum+=dst
///         sum+=pdu.cmd
///         let pduContent = pdu.content
///         sum+=Byte(pduContent.count)
///         pduContent.forEach { e in
///             sum+=e
///         }
///         return sum
///     }
///
///     init(sync: Byte, dst: Byte, pdu: any IPDU) {
///         self.sync = sync
///         self.dst = dst
///         self.pdu = pdu
///     }
/// }
/// ```
public protocol ISDU: Equatable {
    var pdu: any IPDU { get }
    var content: ByteArray { get }
}

public enum BundleType: String {
    case request, response, timeout, exception, biz_fail
}

public struct Bundle {
    // 当 type = request 时，为请求数据
    // 当 type = response 时，为成功的响应数据
    // 当 type = timeout 时，为请求数据
    // 当 type = exception 时，为请求数据，设计用于发送失败
    // 当 type = biz_fail 时，为失败的响应数据，
    let sdu: any ISDU
    let type: BundleType

    init(sdu: any ISDU, type: BundleType) {
        self.sdu = sdu
        self.type = type
    }
}

/// SDU 分析器
/// ```
/// //a demo implemention
/// struct SduAnalyzer: ISduAnalyzer {
///     func analyze(data: ByteArray) -> any Collection<ISDU> {
///         return [SDU(sync: 0, dst: 0, pdu: PDU(cmd: 0, data: []))]
///     }
/// }
/// ```
public protocol ISduAnalyzer {
    func analyze(data: ByteArray) -> any Collection<ISDU>
}
