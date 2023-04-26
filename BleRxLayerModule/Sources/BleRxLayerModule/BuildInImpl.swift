//
//  File.swift
//
//
//  Created by macmini on 2023/4/19.
//

import Foundation

struct PDU: IPDU, Equatable {
    let cmd: Byte
    let dataSize: Byte

    let content: ByteArray

    init(cmd: Byte, data: ByteArray) {
        self.cmd = cmd
        self.dataSize = Byte(data.count)
        self.content = data
    }
}

struct SDU: ISDU, Equatable {
    static func == (lhs: SDU, rhs: SDU) -> Bool {
        return lhs.sync == rhs.sync
            && lhs.dst == rhs.dst
            && lhs.content == rhs.content
    }

    let sync: Byte
    let dst: Byte
    var pdu: any IPDU

    var content: ByteArray {
        var tmp = ByteArray()
        tmp.append(sync)
        tmp.append(dst)
        tmp.append(pdu.cmd)
        tmp.append(contentsOf: pdu.content)
        tmp.append(checksum())
        return tmp
    }

    func checksum() -> Byte {
        var sum: Byte = 0
        sum+=sync
        sum+=dst
        sum+=pdu.cmd
        let pduContent = pdu.content
        sum+=Byte(pduContent.count)
        pduContent.forEach { e in
            sum+=e
        }
        return sum
    }

    init(sync: Byte, dst: Byte, pdu: any IPDU) {
        self.sync = sync
        self.dst = dst
        self.pdu = pdu
    }
}

private extension Date {
    /// 获取当前 秒级 时间戳 - 10位
    var timeStamp: Int {
        let timeInterval: TimeInterval = timeIntervalSince1970
        let timeStamp = Int(timeInterval)
        return timeStamp
//        return "\(timeStamp)"
    }

    /// 获取当前 毫秒级 时间戳 - 13位
    var milliStamp: CLongLong {
        let timeInterval: TimeInterval = timeIntervalSince1970
        let millisecond = CLongLong(round(timeInterval * 1000))
        return millisecond
//        return "\(millisecond)"
    }
}

let SYNC_FLAG: Byte = 0x5a

let TLM_ADDRESS: Byte = 0x81
let PCON_ADDRESS: Byte = 0x80
let IPG_ADDRESS: Byte = 0x00
// let TLM_ADDRESS: Byte = 0x81

private class SduFsm {
    let status_sync = 0
    let status_dst = 1
    let status_checksum = 2
    let status_cmd = 3
    let status_datasize = 4
    let status_data = 5
    let status_received = 0x80
    let time_out = CLongLong(1000)

    let watch = Stopwatch()
    var state: Int

    private var checksum: Byte = 0
    private var dst: Byte = 0
    private var cmd: Byte = 0
    private var dataSize: Byte = 0
    private var data: ByteArray = .init()

    init() {
        self.state = status_sync
    }

    func frameTimeOut() -> Bool {
        return watch.getElapsedTime() >= time_out
    }

    func frameTimeReset() {
        watch.reset().start()
    }

    func collect() -> SDU {
        return SDU(sync: SYNC_FLAG, dst: dst, pdu: PDU(cmd: cmd, data: data))
    }

    func reset() {
        state = status_sync

        checksum = 0
        dst = 0
        cmd = 0
        dataSize = 0
        data = .init()
    }

    func feed(b: Byte) -> Int {
        if frameTimeOut() {
            reset()
        }
        frameTimeReset()
        switch state {
            case status_sync:
                if b != SYNC_FLAG {
                    break
                }
                checksum = SYNC_FLAG
                state = status_dst
            case status_dst:
                dst = b
                checksum+=b
                state = status_cmd
            case status_cmd:
                cmd = b
                checksum+=b
                state = status_datasize
            case status_datasize:
                dataSize = b
                checksum+=b
                data = .init()
                state = dataSize > 0 ? status_data : status_checksum
            case status_data:
                data.append(b)
                checksum+=b
                if data.count >= dataSize {
                    state = status_checksum
                }
            case status_checksum:
                // 校验和一致则接受完成，不一致则全部丢弃，重新开始接受
                state = checksum == b ? status_received : status_sync
                watch.stop()
            case status_received:
                // 外界未收集数据，丢弃新内容
                break
            default:
                state = status_sync
        }
        return state
    }
}

private class Stopwatch {
    var startStamp: CLongLong = 0
    var stopStamp: CLongLong = 0
    var running: Bool = false

    init() {}

    func start() -> Stopwatch {
        startStamp = Date().milliStamp
        running = true
        return self
    }

    func stop() -> Stopwatch {
        stopStamp = Date().milliStamp
        running = false
        return self
    }

    func reset() -> Stopwatch {
        return stop()
    }

    func getElapsedTime() -> CLongLong {
        if running {
            return Date().milliStamp - startStamp
        } else {
            return stopStamp - startStamp
        }
    }
}

public struct SduAnalyzer: ISduAnalyzer {
    private let fsm = SduFsm()
    public func analyze(data: ByteArray) -> any Collection<ISDU> {
        var ret = [any ISDU]()
        data.forEach { b in
            let state = fsm.feed(b: b)
            if state == fsm.status_received {
                ret.append(fsm.collect())
                fsm.reset()
            }
        }
        return ret
    }
}
