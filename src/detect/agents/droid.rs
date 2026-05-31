use super::super::{has_braille_spinner, AgentState};

/// Droid detection.
///
/// Working: braille spinner line (⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏) + "ESC to stop". No standalone
///          "ESC to stop" fallback — the phrase can appear in response content
///          (e.g. explaining a fix), which would cause false Working.
/// Blocked: EXECUTE approval prompt with selection box ("Yes, allow" / "No, cancel")
///          + "Use ↑↓ to navigate, Enter to select"; or "Ask User" / custom-answer prompts.
/// Idle: prompt box visible, no spinner, no selection prompt.
pub(super) fn detect(content: &str) -> AgentState {
    let lower = content.to_lowercase();

    // Working checks first: a live braille spinner + "ESC to stop" is a strong
    // signal the agent is actively working, even if stale "Ask User" text from a
    // previous prompt is still visible in the detection window. No standalone
    // "ESC to stop" fallback — the phrase can appear in response content.
    if has_braille_spinner(content) && lower.contains("esc to stop") {
        return AgentState::Working;
    }

    // Blocked: EXECUTE approval prompt with selection UI chrome
    // Primary (AND): structural keyword + chrome text = certain
    let has_execute = content.contains("EXECUTE");
    let has_selection_chrome = lower.contains("enter to select")
        || lower.contains("↑↓ to navigate")
        || lower.contains("esc to cancel");
    let has_selection_options = lower.contains("> yes, allow") || lower.contains("> no, cancel");

    if has_execute && (has_selection_chrome || has_selection_options) {
        return AgentState::Blocked;
    }
    // Secondary: selection chrome + options together (no EXECUTE needed)
    if has_selection_chrome && has_selection_options {
        return AgentState::Blocked;
    }

    // Blocked: standalone "Ask User" or custom-answer prompts.
    let has_ask_user = lower.contains("ask user");
    let has_custom_answer_prompt = lower.contains("or type your own answer");
    if has_ask_user || has_custom_answer_prompt {
        return AgentState::Blocked;
    }

    AgentState::Idle
}
