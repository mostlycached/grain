// PIIRedactor.swift
// On-device PII detection using Apple NLTagger

import Foundation
import NaturalLanguage

/// Uses Apple's NLTagger to detect and redact PII before sending to Gemini
struct PIIRedactor {
    
    /// Entities to detect and redact
    enum EntityType: String, CaseIterable {
        case person = "[PERSON]"
        case place = "[PLACE]"
        case organization = "[ORG]"
    }
    
    /// Redacts PII from text using on-device NLP
    /// - Parameter text: The input text to redact
    /// - Returns: Text with PII replaced by tokens
    static func redact(_ text: String) -> String {
        let tagger = NLTagger(tagSchemes: [.nameType])
        tagger.string = text
        
        var result = text
        var replacements: [(Range<String.Index>, String)] = []
        
        // Find all named entities
        tagger.enumerateTags(
            in: text.startIndex..<text.endIndex,
            unit: .word,
            scheme: .nameType,
            options: [.omitWhitespace, .omitPunctuation, .joinNames]
        ) { tag, tokenRange in
            guard let tag = tag else { return true }
            
            switch tag {
            case .personalName:
                replacements.append((tokenRange, EntityType.person.rawValue))
            case .placeName:
                replacements.append((tokenRange, EntityType.place.rawValue))
            case .organizationName:
                replacements.append((tokenRange, EntityType.organization.rawValue))
            default:
                break
            }
            return true
        }
        
        // Apply replacements in reverse order to preserve indices
        for (range, replacement) in replacements.reversed() {
            result.replaceSubrange(range, with: replacement)
        }
        
        // Also remove common PII patterns with regex
        result = redactPatterns(result)
        
        return result
    }
    
    /// Additional pattern-based redaction for things NLTagger might miss
    private static func redactPatterns(_ text: String) -> String {
        var result = text
        
        let patterns: [(pattern: String, replacement: String)] = [
            // Phone numbers
            (#"\+?1?[-.\s]?\(?\d{3}\)?[-.\s]?\d{3}[-.\s]?\d{4}"#, "[PHONE]"),
            // Email addresses
            (#"[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}"#, "[EMAIL]"),
            // SSN
            (#"\d{3}-\d{2}-\d{4}"#, "[SSN]"),
            // Credit card (basic)
            (#"\d{4}[-\s]?\d{4}[-\s]?\d{4}[-\s]?\d{4}"#, "[CARD]"),
        ]
        
        for (pattern, replacement) in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                result = regex.stringByReplacingMatches(
                    in: result,
                    range: NSRange(result.startIndex..., in: result),
                    withTemplate: replacement
                )
            }
        }
        
        return result
    }
    
    /// Returns a report of what was redacted (for transparency)
    static func redactionReport(_ text: String) -> [String: Int] {
        let redacted = redact(text)
        var counts: [String: Int] = [:]
        
        for entity in EntityType.allCases {
            let count = redacted.components(separatedBy: entity.rawValue).count - 1
            if count > 0 {
                counts[entity.rawValue] = count
            }
        }
        
        return counts
    }
}
