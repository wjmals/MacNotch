import Darwin
import CoreAudio

enum SystemMetrics {

    static func cpuUsage() -> Double {
        var info  = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info>.size / MemoryLayout<integer_t>.size)
        let kr = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        guard kr == KERN_SUCCESS else { return 0 }
        let u = Double(info.cpu_ticks.0); let s = Double(info.cpu_ticks.1)
        let i = Double(info.cpu_ticks.2); let n = Double(info.cpu_ticks.3)
        let t = u + s + i + n
        return t > 0 ? ((u + s + n) / t) * 100 : 0
    }

    static func systemMemoryGB() -> Double {
        var vm    = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        let kr = withUnsafeMutablePointer(to: &vm) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard kr == KERN_SUCCESS else { return 0 }
        let used = Double(vm.active_count + vm.wire_count + vm.compressor_page_count)
        return (used * Double(vm_kernel_page_size)) / (1024 * 1024 * 1024)
    }

    static func getVolume() -> Float {
        guard let dev = defaultDev() else { return 0.5 }
        var vol: Float = 0.5; var sz = UInt32(MemoryLayout<Float>.size)
        var addr = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput, mElement: kAudioObjectPropertyElementMain)
        AudioObjectGetPropertyData(dev, &addr, 0, nil, &sz, &vol)
        return vol
    }

    static func setVolume(_ v: Float) {
        NSAppleScript(source: "set volume output volume \(Int(max(0,min(1,v))*100))")?.executeAndReturnError(nil)
    }

    private static func defaultDev() -> AudioDeviceID? {
        var dev  = AudioDeviceID(0); var sz = UInt32(MemoryLayout<AudioDeviceID>.size)
        var addr = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        return AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &sz, &dev) == noErr ? dev : nil
    }
}
