import Foundation

extension String {
    /// 截取到指定长度
    func truncate(to length: Int, trailing: String = "...") -> String {
        count > length ? String(prefix(length)) + trailing : self
    }

    /// 是否为空或仅空白
    var isBlank: Bool {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// 移除首尾空白
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
