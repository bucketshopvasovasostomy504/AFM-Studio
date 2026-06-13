import SwiftUI

struct StudioConversationListView: View {
    let conversations: [ConversationRecord]
    @Binding var selectedConversationID: UUID?
    let onNewConversation: () -> Void
    let onDelete: (ConversationRecord) -> Void

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if conversations.isEmpty {
                emptyState
            } else {
                list
            }
        }
        .navigationTitle("AFM Studio")
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Chats")
                    .font(.title2.weight(.semibold))
                Text("\(conversations.count) conversations")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("New", action: onNewConversation)
                .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    private var list: some View {
        List {
            ForEach(conversations) { conversation in
                Button {
                    selectedConversationID = conversation.id
                } label: {
                    StudioConversationRowView(
                        conversation: conversation,
                        isActive: selectedConversationID == conversation.id
                    )
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button("Delete", role: .destructive) {
                        onDelete(conversation)
                    }
                }
            }
            .onDelete { offsets in
                offsets
                    .map { conversations[$0] }
                    .forEach(onDelete)
            }
        }
        .listStyle(.sidebar)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("No chats yet")
                .font(.headline)
            Text("Create a chat to start testing Apple Foundation Models.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button("New Chat", action: onNewConversation)
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding()
    }
}

private struct StudioConversationRowView: View {
    let conversation: ConversationRecord
    let isActive: Bool

    private var orderedMessages: [MessageRecord] {
        conversation.messages.sorted { $0.createdAt < $1.createdAt }
    }

    private var subtitle: String {
        guard let lastMessage = orderedMessages.last else {
            return "Start chatting to add messages."
        }

        let trimmed = lastMessage.content.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Waiting for response." : trimmed
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    if isActive {
                        Text("Active")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.accentColor)
                            .clipShape(Capsule())
                    }
                    Text(conversation.title)
                        .font(.headline)
                        .lineLimit(1)
                }

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                Text(conversation.updatedAt, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if conversation.messages.isEmpty == false {
                    Text("\(conversation.messages.count)")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens this conversation")
    }
}
