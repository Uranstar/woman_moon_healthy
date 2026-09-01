import SwiftUI

struct AIAssistantView: View {
    @EnvironmentObject private var appState: AppState
    @State private var messages: [ChatMessage] = [
        ChatMessage(
            id: 0,
            role: .assistant,
            content: "你好！我是小月 🌙\n你的AI健康助手。我可以帮你：\n• 解读身体信号\n• 分析饮食营养\n• 提供运动建议\n• 情绪疏导\n\n你现在处于\(CyclePhase.follicular.description)，有什么我可以帮你的？",
            timestamp: Date()
        )
    ]
    @State private var inputText = ""
    @State private var isSending = false
    @FocusState private var isInputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // 聊天记录
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(messages) { message in
                            ChatBubble(message: message)
                                .id(message.id)
                        }

                        if isSending {
                            HStack {
                                Spacer()
                                ProgressView("小月思考中...")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding()
                            }
                        }
                    }
                    .padding()
                }
                .scrollDismissesKeyboard(.immediately)
                .onTapGesture {
                    isInputFocused = false
                }
                .onChange(of: messages.count) { _, _ in
                    if let last = messages.last {
                        withAnimation {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }

            // 快捷问题
            quickQuestions

            // 输入框
            inputBar
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("AI 助手")
        .navigationBarTitleDisplayMode(.inline)
        .dismissKeyboardToolbar()
    }

    // MARK: - 快捷问题
    private var quickQuestions: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(suggestedQuestions, id: \.self) { question in
                    Button(action: { sendMessage(question) }) {
                        Text(question)
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(.white)
                            )
                            .foregroundColor(Color(hex: "#E91E63"))
                            .overlay(
                                Capsule()
                                    .stroke(Color(hex: "#E91E63").opacity(0.3), lineWidth: 1)
                            )
                    }
                }
                .padding(.vertical, 4)
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - 输入栏
    private var inputBar: some View {
        HStack(spacing: 12) {
            TextField("输入你的问题...", text: $inputText, axis: .vertical)
                .textFieldStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color(.systemGray6))
                )
                .focused($isInputFocused)
                .lineLimit(1...4)
                .onSubmit { sendMessage(inputText) }

            Button(action: { sendMessage(inputText) }) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(
                        inputText.trimmingCharacters(in: .whitespaces).isEmpty ?
                        Color(.systemGray3) : Color(hex: "#E91E63")
                    )
            }
            .disabled(inputText.trimmingCharacters(in: .whitespaces).isEmpty || isSending)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.white)
    }

    // MARK: - 发送消息
    private func sendMessage(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !isSending else { return }

        let userMsg = ChatMessage(
            id: messages.count,
            role: .user,
            content: trimmed,
            timestamp: Date()
        )
        messages.append(userMsg)
        inputText = ""
        isSending = true

        // 调用 Claude API
        Task {
            do {
                let context = AIChatContext(
                    cyclePhase: appState.currentCyclePhase,
                    age: 25,
                    goals: appState.userGoals,
                    bmi: 22.0
                )
                let reply = try await AIService.shared.chat(
                    userMessage: trimmed,
                    context: context
                )
                let assistantMsg = ChatMessage(
                    id: messages.count,
                    role: .assistant,
                    content: reply,
                    timestamp: Date()
                )
                messages.append(assistantMsg)
            } catch {
                let errorMsg = ChatMessage(
                    id: messages.count,
                    role: .assistant,
                    content: "抱歉，我暂时无法回答。请检查网络或稍后再试。如需紧急帮助，建议咨询专业医生。",
                    timestamp: Date()
                )
                messages.append(errorMsg)
            }
            isSending = false
        }
    }

    private var suggestedQuestions: [String] {
        [
            "我今天适合做什么运动？",
            "经期腹痛怎么办？",
            "推荐今天的食谱",
            "为什么最近情绪波动大？",
            "排卵期有什么注意事项？",
            "帮我分析一下我的饮食",
        ]
    }
}

// MARK: - 聊天消息模型
struct ChatMessage: Identifiable {
    let id: Int
    let role: MessageRole
    let content: String
    let timestamp: Date
}

enum MessageRole {
    case user
    case assistant
}

// MARK: - 聊天气泡
struct ChatBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack(alignment: .top) {
            if message.role == .assistant {
                // 助手头像
                Image(systemName: "moon.stars.fill")
                    .font(.title3)
                    .foregroundColor(Color(hex: "#E91E63"))
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(Color(hex: "#FCE4EC"))
                    )
            } else {
                Spacer()
            }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .font(.subheadline)
                    .padding(12)
                    .background(
                        message.role == .user ?
                        Color(hex: "#E91E63") : Color(.systemGray6)
                    )
                    .foregroundColor(message.role == .user ? .white : .primary)
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            if message.role == .user {
                Image(systemName: "person.circle.fill")
                    .font(.title3)
                    .foregroundColor(Color(hex: "#9C27B0"))
                    .frame(width: 32, height: 32)
            } else {
                Spacer()
            }
        }
    }
}
