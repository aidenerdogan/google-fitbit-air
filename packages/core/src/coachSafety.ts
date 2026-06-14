export interface CoachSafetyDecision {
  allowed: boolean;
  reason: "wellness_only" | "medical_claim" | "diagnosis_or_treatment";
  matchedTerms: string[];
  safeReply: string;
}

const DIAGNOSIS_OR_TREATMENT_TERMS = [
  "diagnose",
  "diagnosis",
  "treat",
  "treatment",
  "prescribe",
  "prescription",
  "medication",
  "dose",
  "dosage",
  "cure",
  "disease",
  "condition",
  "doctor",
  "emergency"
];

const MEDICAL_CLAIM_TERMS = [
  "you have",
  "you likely have",
  "this means you have",
  "you are sick",
  "you need medical",
  "stop taking",
  "start taking",
  "change your medication"
];

export function reviewCoachResponse(text: string): CoachSafetyDecision {
  const normalized = text.toLowerCase();
  const diagnosisMatches = matchedTerms(normalized, DIAGNOSIS_OR_TREATMENT_TERMS);
  const medicalClaimMatches = matchedTerms(normalized, MEDICAL_CLAIM_TERMS);

  if (diagnosisMatches.length > 0) {
    return blockedDecision("diagnosis_or_treatment", diagnosisMatches);
  }

  if (medicalClaimMatches.length > 0) {
    return blockedDecision("medical_claim", medicalClaimMatches);
  }

  return {
    allowed: true,
    reason: "wellness_only",
    matchedTerms: [],
    safeReply: text
  };
}

export function wellnessCoachBoundary(): string {
  return [
    "Explain only wellness trends, data gaps, and uncertainty.",
    "Do not diagnose, treat, prescribe, or claim a medical condition.",
    "Tell the user to contact a qualified professional for medical concerns."
  ].join(" ");
}

function matchedTerms(text: string, terms: string[]): string[] {
  return terms.filter((term) => text.includes(term));
}

function blockedDecision(reason: Exclude<CoachSafetyDecision["reason"], "wellness_only">, matchedTerms: string[]): CoachSafetyDecision {
  return {
    allowed: false,
    reason,
    matchedTerms,
    safeReply: "I can explain wellness trends and data gaps, but I cannot diagnose, treat, prescribe, or make medical claims."
  };
}
