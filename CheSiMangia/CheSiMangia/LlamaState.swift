import Foundation

@MainActor
class LlamaState: ObservableObject {
    @Published var messages = ""
    private var llamaContext: LlamaContext?

    func completeToString(text: String, maxSteps: Int = 6000) async -> String {
        guard let llamaContext else { return "" }

        await clear()
        await llamaContext.completion_init(text: text)

        var buffer = ""
        var steps = 0
        while await !llamaContext.is_done {
            buffer += await llamaContext.completion_loop()
            steps += 1
            if steps > maxSteps { break }
        }

        await llamaContext.clear()
        return buffer
    }
    
    
    func loadModel() throws {
        let filename = "Phi-3-mini-4k-instruct-Q4_K_M"
        guard let modelPath = Bundle.main.path(forResource: filename, ofType: "gguf") else {
            print("[LLAMA] Modello \(filename).gguf non trovato nel bundle")
            throw LlamaStateError.modelNotFound("\(filename).gguf")
        }
        do {
            llamaContext = try LlamaContext.create_context(path: modelPath)
            print("[LLAMA] Modello caricato da \(modelPath)")
        } catch {
            print("[LLAMA] Creazione contesto fallita: \(error)")
            throw LlamaStateError.contextInitFailed
        }
    }

    func complete(text: String) async {
        guard let llamaContext else { return }

        await llamaContext.completion_init(text: text)
        Task.detached { [weak self] in
            guard let self else { return }
            while await !llamaContext.is_done {
                let result = await llamaContext.completion_loop()
                await MainActor.run {
                    self.messages += result
                }
            }
            await MainActor.run {
                self.messages += "\n"
            }
            await llamaContext.clear()
        }
    }

    func clear() async {
        guard let llamaContext else { return }
        await llamaContext.clear()
        messages = ""
    }
    
    /// Garantisce che il modello sia caricato prima dell’uso.
    private func ensureLoaded() async {
        if llamaContext == nil {
            try? loadModel()
        }
    }

    /// Avvia la completion con il prompt fornito.
    func completion_init(text: String) async {
        await ensureLoaded()
        guard let ctx = llamaContext else { return }
        await ctx.completion_init(text: text)
    }

    /// Esegue un passo di decoding e restituisce il chunk di testo generato.
    func completion_loop() async -> String {
        guard let ctx = llamaContext else { return "" }
        return await ctx.completion_loop()
    }

    /// Stato “done” esposto come property async.
    var is_done: Bool {
        get async {
            guard let ctx = llamaContext else { return true }
            return await ctx.is_done
        }
    }
    
    func completeToString(text: String, maxSteps: Int = 6000, endMarker: String? = nil) async -> String {
        await completion_init(text: text)

        var buffer = ""
        var steps = 0

        while await !is_done {
            let chunk = await completion_loop()
            buffer += chunk

            if let endMarker, let r = buffer.range(of: endMarker) {
                buffer = String(buffer[..<r.lowerBound])
                break
            }

            steps += 1
            if steps > maxSteps { break }
        }

        return buffer
    }
}

enum LlamaStateError: Error {
    case modelNotFound(String)
    case contextInitFailed
}
