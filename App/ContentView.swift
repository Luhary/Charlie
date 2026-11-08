import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: CompanionStore
    @ObservedObject private var live = LiveActivityManager.shared
    @FocusState private var inputFocused: Bool
    @State private var showSettings = false
    @State private var showNotes = false
    @State private var blink = false

    var body: some View {
        ZStack {
            Color(red: 0.11, green: 0.095, blue: 0.105).ignoresSafeArea()
            VStack(spacing: 20) {
                HStack {
                    Spacer()
                    Button { showNotes = true } label: {
                        Image(systemName: "note.text")
                            .font(.title3)
                            .foregroundStyle(.gray)
                    }
                    .padding(.trailing, 14)
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.title3)
                            .foregroundStyle(.gray)
                    }
                }

                Spacer(minLength: 0)

                avatar
                    .onTapGesture { store.startListening() }

                ScrollView {
                    Text(displayText)
                        .font(.system(.title3, design: .serif))
                        .foregroundStyle(Color(red: 0.91, green: 0.85, blue: 0.80))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }
                .frame(maxHeight: 190)

                if let pending = store.pending {
                    pendingView(pending)
                }

                inputBar

                Button(live.isActive ? "Dynamic Island: выключить" : "Dynamic Island: включить") {
                    Task { await toggleLive() }
                }
                .font(.footnote)
                .foregroundStyle(.gray)
            }
            .padding()
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showSettings) { SettingsView() }
        .sheet(isPresented: $showNotes) { NotesView() }
        .onChange(of: store.pendingAction, initial: true) { _, action in
            guard let action else { return }
            store.pendingAction = nil
            switch action {
            case .listen: store.startListening()
            case .type: inputFocused = true
            }
        }
    }

    // Покой: никакой постоянной анимации, только редкое моргание (почти бесплатно для батареи).
    // Активные состояния: лёгкая анимация 30 кадров/с, пока компаньон слушает/думает/говорит.
    private var avatar: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !store.mood.animates)) { ctx in
            let t = store.mood.animates ? ctx.date.timeIntervalSinceReferenceDate : 0
            CharlieAvatar(mood: store.mood, size: 290, phase: t, blink: blink)
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(Double.random(in: 2.5...5.0) * 1_000_000_000))
                withAnimation(.easeInOut(duration: 0.08)) { blink = true }
                try? await Task.sleep(nanoseconds: 140_000_000)
                withAnimation(.easeInOut(duration: 0.08)) { blink = false }
            }
        }
    }

    private var displayText: String {
        if store.mood == .listening {
            return store.liveTranscript.isEmpty ? "Слушаю…" : store.liveTranscript
        }
        return store.lastAnswer
    }

    private var inputBar: some View {
        HStack(spacing: 10) {
            TextField("Написать…", text: $store.input)
                .textFieldStyle(.roundedBorder)
                .focused($inputFocused)
                .submitLabel(.send)
                .onSubmit { send() }
            Button { store.startListening() } label: {
                Image(systemName: "mic.fill").font(.title2)
            }
            Button { send() } label: {
                Image(systemName: "arrow.up.circle.fill").font(.title)
            }
        }
    }

    @ViewBuilder
    private func pendingView(_ pending: PendingCommand) -> some View {
        switch pending {
        case .chooseContact(let matches):
            VStack(spacing: 8) {
                ForEach(matches) { match in
                    Button { store.choose(match) } label: {
                        Text("\(match.name) · \(match.number)").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.gray)
                }
                Button("Отмена") { store.cancelPending() }
                    .buttonStyle(.borderless)
                    .tint(.gray)
            }
        case .event, .alarm:
            HStack(spacing: 12) {
                Button(confirmTitle(pending)) { store.confirmPending() }
                    .buttonStyle(.borderedProminent)
                    .tint(Color(red: 0.55, green: 0.08, blue: 0.20))
                Button("Отмена") { store.cancelPending() }
                    .buttonStyle(.bordered)
                    .tint(.gray)
            }
        }
    }

    private func confirmTitle(_ pending: PendingCommand) -> String {
        if case .alarm = pending { return "Поставить" }
        return "Записать"
    }

    private func send() {
        let text = store.input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        store.input = ""
        inputFocused = false
        store.ask(text)
    }

    private func toggleLive() async {
        if live.isActive {
            await live.stop()
        } else {
            live.start(mood: store.mood, message: "Чарли здесь 🖤")
        }
    }
}
