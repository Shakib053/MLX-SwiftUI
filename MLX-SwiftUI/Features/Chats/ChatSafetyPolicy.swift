import Foundation

enum ChatSafetyCategory: String, CaseIterable, Equatable, Sendable {
    case sexualContentInvolvingMinors
    case explicitSexualContent
    case violenceOrWeapons
    case selfHarm
    case illegalDrugProduction
    case hateOrTargetedHarassment
    case credentialTheftOrMaliciousCyberActivity

    var title: String {
        switch self {
        case .sexualContentInvolvingMinors:
            return "sexual content involving minors"
        case .explicitSexualContent:
            return "explicit sexual content"
        case .violenceOrWeapons:
            return "violent or weapon-related instructions"
        case .selfHarm:
            return "self-harm assistance"
        case .illegalDrugProduction:
            return "illegal drug production"
        case .hateOrTargetedHarassment:
            return "hate or targeted harassment"
        case .credentialTheftOrMaliciousCyberActivity:
            return "credential theft or malicious cyber activity"
        }
    }

    var refusalMessage: String {
        switch self {
        case .sexualContentInvolvingMinors:
            return "I can’t help create or describe sexual content involving minors."
        case .explicitSexualContent:
            return "I can’t help create explicit sexual content. I can help with a non-explicit or educational alternative."
        case .violenceOrWeapons:
            return "I can’t help with instructions to harm someone, build a weapon, or use one to injure people. I can help with safety, prevention, or legal information."
        case .selfHarm:
            return "I’m sorry you’re dealing with this. I can’t help with instructions for self-harm. Please contact local emergency services or a trusted person who can stay with you right now."
        case .illegalDrugProduction:
            return "I can’t help make, extract, or increase the potency of illegal drugs. I can help with health, treatment, or harm-prevention information."
        case .hateOrTargetedHarassment:
            return "I can’t help create threats, hateful content, or targeted harassment. I can help rewrite this in a respectful and non-targeted way."
        case .credentialTheftOrMaliciousCyberActivity:
            return "I can’t help steal credentials, take over accounts, or create malware or phishing tools. I can help with defensive security and account protection."
        }
    }
}

enum ChatSafetyDecision: Equatable, Sendable {
    case allow
    case blocked(ChatSafetyCategory)
}

enum ChatSafetyGate {
    static func evaluate(_ text: String) -> ChatSafetyDecision {
        let normalized = normalize(text)
        guard !normalized.isEmpty else { return .allow }

        if containsMinorSexualContent(in: normalized) {
            return .blocked(.sexualContentInvolvingMinors)
        }
        if containsSelfHarmRequest(in: normalized) {
            return .blocked(.selfHarm)
        }
        if containsExplicitSexualRequest(in: normalized) {
            return .blocked(.explicitSexualContent)
        }
        if containsViolenceOrWeaponRequest(in: normalized) {
            return .blocked(.violenceOrWeapons)
        }
        if containsIllegalDrugProductionRequest(in: normalized) {
            return .blocked(.illegalDrugProduction)
        }
        if containsHateOrHarassmentRequest(in: normalized) {
            return .blocked(.hateOrTargetedHarassment)
        }
        if containsMaliciousCyberRequest(in: normalized) {
            return .blocked(.credentialTheftOrMaliciousCyberActivity)
        }

        return .allow
    }

    private static func normalize(_ text: String) -> String {
        let folded = text.folding(
            options: [.caseInsensitive, .diacriticInsensitive],
            locale: .current
        )
        let alphanumeric = folded.unicodeScalars.map { scalar in
            CharacterSet.alphanumerics.contains(scalar) ? String(scalar) : " "
        }.joined()

        // Handle common leetspeak variants in the classification copy only.
        let leetspeak = alphanumeric
            .replacingOccurrences(of: "0", with: "o")
            .replacingOccurrences(of: "1", with: "i")
            .replacingOccurrences(of: "3", with: "e")
            .replacingOccurrences(of: "4", with: "a")
            .replacingOccurrences(of: "5", with: "s")
            .replacingOccurrences(of: "7", with: "t")

        return leetspeak
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func containsAny(_ terms: [String], in text: String) -> Bool {
        terms.contains { text.contains($0) }
    }

    private static func containsMinorSexualContent(in text: String) -> Bool {
        let minorSignals = [
            "underage", "minor", "child", "children", "kid", "kids", "preteen",
            "teen", "schoolgirl", "schoolboy", "young girl", "young boy"
        ]
        let sexualSignals = [
            "sex", "sexual", "porn", "nude", "naked", "nsfw", "erotic", "masturb",
            "penetrat", "blowjob", "oral sex", "explicit"
        ]
        return containsAny(minorSignals, in: text) && containsAny(sexualSignals, in: text)
    }

    private static func containsExplicitSexualRequest(in text: String) -> Bool {
        let sexualContent = [
            "porn", "pornography", "pornographic", "nude", "nudes", "nsfw", "erotic",
            "masturb", "blowjob", "sexual roleplay", "explicit sex", "sex scene"
        ]
        let generationIntent = [
            "generate", "create", "write", "describe", "roleplay", "show", "draw",
            "make", "produce", "send", "compose"
        ]
        return containsAny(sexualContent, in: text) && containsAny(generationIntent, in: text)
    }

    private static func containsSelfHarmRequest(in text: String) -> Bool {
        containsAny([
            "suicide", "suicidal", "kill myself", "end my life", "self harm",
            "cut myself", "overdose on", "hang myself", "jump off", "hurt myself"
        ], in: text)
    }

    private static func containsViolenceOrWeaponRequest(in text: String) -> Bool {
        let directHarm = [
            "kill someone", "shoot someone", "stab someone", "assassinate",
            "poison someone", "make a bomb", "build a bomb", "how to make explosives",
            "how to build a weapon", "weapon instructions", "attack a person",
            "harm someone", "how to kill a person", "how to murder",
            "how to shoot a person", "how to stab a person", "how to poison a person",
            "how to torture", "instructions for violence", "how to commit violence"
        ]
        if containsAny(directHarm, in: text) {
            return true
        }

        let weapons = [
            "bomb", "explosive", "firearm", "gun", "rifle", "pistol", "weapon",
            "poison", "incendiary", "ammunition"
        ]
        let harmfulIntent = [
            "how to", "instructions", "steps", "guide", "build", "make", "assemble",
            "obtain", "acquire", "conceal", "hide", "deploy", "use"
        ]
        let safeContext = [
            "safe storage", "firearm safety", "prevent", "prevention", "defensive",
            "defense", "historical", "history", "legal"
        ]

        return containsAny(weapons, in: text)
            && containsAny(harmfulIntent, in: text)
            && !containsAny(safeContext, in: text)
    }

    private static func containsIllegalDrugProductionRequest(in text: String) -> Bool {
        let drugs = [
            "meth", "fentanyl", "cocaine", "heroin", "mdma", "ecstasy", "lsd",
            "crack", "amphetamine", "opioid", "illegal drug"
        ]
        let productionIntent = [
            "make", "cook", "synthesize", "manufacture", "produce", "extract", "purify",
            "recipe", "precursor", "increase potency", "stronger dose"
        ]
        let safeContext = [
            "prevent", "prevention", "treatment", "recovery", "overdose response",
            "health", "medical", "history", "historical", "legal"
        ]

        return containsAny(drugs, in: text)
            && containsAny(productionIntent, in: text)
            && !containsAny(safeContext, in: text)
    }

    private static func containsHateOrHarassmentRequest(in text: String) -> Bool {
        let directAbuse = [
            "deserve to die", "should be killed", "go back to", "dehumanize",
            "exterminate", "genocide", "racial slur", "target this person"
        ]
        if containsAny(directAbuse, in: text) {
            return true
        }

        let targetSignals = [
            "women", "men", "gay", "lgbt", "trans", "muslim", "jewish", "black",
            "asian", "immigrant", "disabled", "minority", "my ex", "coworker",
            "neighbor", "person", "group"
        ]
        let abusiveIntent = [
            "write", "generate", "create", "make", "compose", "send", "post",
            "insult", "harass", "threaten", "dox", "humiliate", "attack", "hate"
        ]
        let abuseSignals = [
            "slur", "hateful", "harassment", "threat", "dehumanize", "inferior",
            "humiliate", "abuse"
        ]

        return containsAny(targetSignals, in: text)
            && containsAny(abusiveIntent, in: text)
            && containsAny(abuseSignals, in: text)
    }

    private static func containsMaliciousCyberRequest(in text: String) -> Bool {
        let directMaliciousRequests = [
            "steal password", "steal passwords", "steal credentials", "credential harvesting",
            "phishing page", "phishing kit", "keylogger", "ransomware", "account takeover",
            "bypass authentication", "exfiltrate passwords", "dump passwords"
        ]
        let defensiveContext = [
            "prevent", "protect", "detect", "defend", "mitigate", "secure",
            "security awareness", "incident response", "authorized", "penetration test",
            "ctf", "capture the flag"
        ]
        if containsAny(directMaliciousRequests, in: text)
            && !containsAny(defensiveContext, in: text) {
            return true
        }

        let maliciousTools = [
            "phishing", "phish", "keylogger", "malware", "ransomware", "credential stuffing",
            "brute force", "account takeover", "exfiltrate", "steal credentials"
        ]
        let credentialTargets = [
            "password", "credential", "login", "api key", "cookie", "token"
        ]
        let maliciousIntent = [
            "steal", "harvest", "capture", "bypass", "exfiltrate", "dump", "crack",
            "brute force", "hijack", "take over"
        ]
        let toolCreationIntent = [
            "build", "write", "create", "make", "code", "script", "how to", "steps",
            "instructions"
        ]

        return (
            (containsAny(maliciousTools, in: text) && containsAny(toolCreationIntent, in: text))
                || (containsAny(credentialTargets, in: text) && containsAny(maliciousIntent, in: text))
        )
            && !containsAny(defensiveContext, in: text)
    }
}
