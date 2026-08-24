#!/usr/bin/env zsh

# Load test helper
source "${0:A:h}/test_helper.zsh"

# Load the config module
source "$PLUGIN_DIR/lib/config.zsh"

# Test functions
test_default_provider() {
    setup_test_env
    unset ZSH_AI_PROVIDER
    source "$PLUGIN_DIR/lib/config.zsh"
    assert_equals "$ZSH_AI_PROVIDER" "anthropic"
    teardown_test_env
}

test_default_ollama_model() {
    setup_test_env
    unset ZSH_AI_OLLAMA_MODEL
    source "$PLUGIN_DIR/lib/config.zsh"
    assert_equals "$ZSH_AI_OLLAMA_MODEL" "llama3.2"
    teardown_test_env
}

test_default_ollama_url() {
    setup_test_env
    unset ZSH_AI_OLLAMA_URL
    source "$PLUGIN_DIR/lib/config.zsh"
    assert_equals "$ZSH_AI_OLLAMA_URL" "http://localhost:11434"
    teardown_test_env
}

test_validates_anthropic_provider() {
    setup_test_env
    export ZSH_AI_PROVIDER="anthropic"
    export ANTHROPIC_API_KEY="test-key"
    _zsh_ai_validate_config >/dev/null 2>&1
    local result=$?
    assert_equals "$result" "0"
    teardown_test_env
}

test_validates_ollama_provider() {
    setup_test_env
    export ZSH_AI_PROVIDER="ollama"
    _zsh_ai_validate_config >/dev/null 2>&1
    local result=$?
    assert_equals "$result" "0"
    teardown_test_env
}

test_rejects_invalid_provider() {
    setup_test_env
    export ZSH_AI_PROVIDER="invalid"
    _zsh_ai_validate_config >/dev/null 2>&1
    local result=$?
    assert_equals "$result" "1"
    teardown_test_env
}

test_validates_gemini_provider() {
    setup_test_env
    export ZSH_AI_PROVIDER="gemini"
    export GEMINI_API_KEY="test-key"
    _zsh_ai_validate_config >/dev/null 2>&1
    local result=$?
    assert_equals "$result" "0"
    teardown_test_env
}

test_validates_openai_provider() {
    setup_test_env
    export ZSH_AI_PROVIDER="openai"
    export OPENAI_API_KEY="test-key"
    _zsh_ai_validate_config >/dev/null 2>&1
    local result=$?
    assert_equals "$result" "0"
    teardown_test_env
}

test_validates_custom_provider() {
      local had_custom_function=$+functions[_zsh_ai_query_custom]
      local saved_custom_function="${functions[_zsh_ai_query_custom]-}"

      {
          setup_test_env
          export ZSH_AI_PROVIDER="custom"

          _zsh_ai_query_custom() {
              return 0
          }

          _zsh_ai_validate_config >/dev/null 2>&1
          assert_equals "$?" "0"
      } always {
          teardown_test_env

          if (( had_custom_function )); then
              functions[_zsh_ai_query_custom]="$saved_custom_function"
          else
              unfunction _zsh_ai_query_custom 2>/dev/null
          fi
      }
}

test_rejects_missing_custom_provider_function() {
      local had_custom_function=$+functions[_zsh_ai_query_custom]
      local saved_custom_function="${functions[_zsh_ai_query_custom]-}"

      {
          setup_test_env
          export ZSH_AI_PROVIDER="custom"
          unfunction _zsh_ai_query_custom 2>/dev/null

          _zsh_ai_validate_config >/dev/null 2>&1
          assert_equals "$?" "1"
      } always {
          teardown_test_env

          if (( had_custom_function )); then
              functions[_zsh_ai_query_custom]="$saved_custom_function"
          else
              unfunction _zsh_ai_query_custom 2>/dev/null
          fi
      }
}

test_comment_hook_enabled_by_default() {
    setup_test_env
    unset ZSH_AI_COMMENT_HOOK
    source "$PLUGIN_DIR/lib/config.zsh"
    _zsh_ai_comment_hook_enabled
    local result=$?
    assert_equals "$result" "0"
    teardown_test_env
}

test_comment_hook_can_be_disabled() {
    setup_test_env
    local value
    for value in false off no 0 disabled FALSE Off; do
        export ZSH_AI_COMMENT_HOOK="$value"
        _zsh_ai_comment_hook_enabled
        assert_equals "$?" "1"
    done
    unset ZSH_AI_COMMENT_HOOK
    teardown_test_env
}

test_default_trigger_is_hash() {
    setup_test_env
    unset ZSH_AI_TRIGGER
    source "$PLUGIN_DIR/lib/config.zsh"
    assert_equals "$ZSH_AI_TRIGGER" "# "
    teardown_test_env
}

# --- Config file loading tests ---

make_config_file() {
    local content="$1"
    local file
    file=$(mktemp)
    printf '%s\n' "$content" > "$file"
    printf '%s' "$file"
}

# Load a fresh copy of config.zsh against ZSH_AI_CONFIG and return the
# value of the named variable.
reload_config_value() {
    local var="$1"
    source "$PLUGIN_DIR/lib/config.zsh"
    printf '%s' "${(P)var}"
}

test_loads_provider_from_config_file() {
    setup_test_env
    local cfg
    cfg=$(make_config_file "ZSH_AI_PROVIDER=gemini")
    export ZSH_AI_CONFIG="$cfg"
    unset ZSH_AI_PROVIDER
    local value
    value=$(reload_config_value ZSH_AI_PROVIDER)
    assert_equals "$value" "gemini"
    rm -f "$cfg"
    teardown_test_env
}

test_loads_api_key_from_config_file() {
    setup_test_env
    local cfg
    cfg=$(make_config_file "ANTHROPIC_API_KEY=file-key")
    export ZSH_AI_CONFIG="$cfg"
    unset ANTHROPIC_API_KEY
    export ZSH_AI_PROVIDER="anthropic"
    source "$PLUGIN_DIR/lib/config.zsh"
    assert_equals "$ANTHROPIC_API_KEY" "file-key"
    _zsh_ai_validate_config >/dev/null 2>&1
    assert_equals "$?" "0"
    rm -f "$cfg"
    teardown_test_env
}

test_env_var_overrides_config_file() {
    setup_test_env
    local cfg
    cfg=$(make_config_file "ZSH_AI_PROVIDER=gemini")
    export ZSH_AI_CONFIG="$cfg"
    export ZSH_AI_PROVIDER="openai"
    local value
    value=$(reload_config_value ZSH_AI_PROVIDER)
    assert_equals "$value" "openai"
    rm -f "$cfg"
    teardown_test_env
}

test_env_api_key_overrides_config_file() {
    setup_test_env
    local cfg
    cfg=$(make_config_file "ANTHROPIC_API_KEY=file-key")
    export ZSH_AI_CONFIG="$cfg"
    export ANTHROPIC_API_KEY="env-key"
    source "$PLUGIN_DIR/lib/config.zsh"
    assert_equals "$ANTHROPIC_API_KEY" "env-key"
    rm -f "$cfg"
    teardown_test_env
}

test_config_file_ignores_comments_and_blank_lines() {
    setup_test_env
    local cfg
    cfg=$(make_config_file $'# a comment

   # indented comment

ZSH_AI_PROVIDER=qwen
')
    export ZSH_AI_CONFIG="$cfg"
    unset ZSH_AI_PROVIDER
    local value
    value=$(reload_config_value ZSH_AI_PROVIDER)
    assert_equals "$value" "qwen"
    rm -f "$cfg"
    teardown_test_env
}

test_config_file_strips_surrounding_quotes() {
    setup_test_env
    local cfg
    cfg=$(make_config_file 'ZSH_AI_TRIGGER=",,"')
    export ZSH_AI_CONFIG="$cfg"
    unset ZSH_AI_TRIGGER
    local value
    value=$(reload_config_value ZSH_AI_TRIGGER)
    assert_equals "$value" ",,"
    rm -f "$cfg"
    teardown_test_env
}

test_missing_config_file_uses_defaults() {
    setup_test_env
    export ZSH_AI_CONFIG="/nonexistent/zsh-ai-test-config"
    unset ZSH_AI_PROVIDER
    local value
    value=$(reload_config_value ZSH_AI_PROVIDER)
    assert_equals "$value" "anthropic"
    teardown_test_env
}

test_config_file_uses_xdg_config_home() {
    setup_test_env
    local xdg cfg
    xdg=$(mktemp -d)
    mkdir -p "$xdg/zsh"
    printf '%s\n' "ZSH_AI_PROVIDER=mistral" > "$xdg/zsh/zsh-ai"
    unset ZSH_AI_CONFIG
    export XDG_CONFIG_HOME="$xdg"
    unset ZSH_AI_PROVIDER
    local value
    value=$(reload_config_value ZSH_AI_PROVIDER)
    assert_equals "$value" "mistral"
    rm -rf "$xdg"
    teardown_test_env
}

test_config_file_inline_comment() {
    setup_test_env
    local cfg
    cfg=$(mktemp)
    printf '%s\n' 'ZSH_AI_PROVIDER="gemini"   # team default' > "$cfg"
    export ZSH_AI_CONFIG="$cfg"
    unset ZSH_AI_PROVIDER
    local value
    value=$(reload_config_value ZSH_AI_PROVIDER)
    assert_equals "$value" "gemini"
    rm -f "$cfg"
    teardown_test_env
}

test_config_file_keeps_hash_inside_quotes() {
    setup_test_env
    local cfg
    cfg=$(mktemp)
    printf '%s\n' 'ZSH_AI_TRIGGER="#"' > "$cfg"
    export ZSH_AI_CONFIG="$cfg"
    unset ZSH_AI_TRIGGER
    local value
    value=$(reload_config_value ZSH_AI_TRIGGER)
    assert_equals "$value" "#"
    rm -f "$cfg"
    teardown_test_env
}

test_config_file_ignores_lines_without_equals() {
    setup_test_env
    local cfg
    cfg=$(mktemp)
    printf '%s\n' 'ZSH_AI_PROVIDER=gemini' 'MALFORMED_NO_EQUALS' 'ZSH_AI_TRIGGER=",,"' > "$cfg"
    export ZSH_AI_CONFIG="$cfg"
    unset ZSH_AI_PROVIDER ZSH_AI_TRIGGER MALFORMED_NO_EQUALS
    source "$PLUGIN_DIR/lib/config.zsh"
    assert_equals "$ZSH_AI_PROVIDER" "gemini"
    assert_equals "$ZSH_AI_TRIGGER" ",,"
    if (( $+MALFORMED_NO_EQUALS )); then
        echo "FAIL: line without '=' should be ignored"
        return 1
    fi
    rm -f "$cfg"
    teardown_test_env
}

# Run tests
echo "Running config tests..."
run_test "Default provider is anthropic" test_default_provider
run_test "Default Ollama model is llama3.2" test_default_ollama_model
run_test "Default Ollama URL is localhost:11434" test_default_ollama_url
run_test "Validates anthropic provider" test_validates_anthropic_provider
run_test "Validates ollama provider" test_validates_ollama_provider
run_test "Rejects invalid provider" test_rejects_invalid_provider
run_test "Validates gemini provider" test_validates_gemini_provider
run_test "Validates openai provider" test_validates_openai_provider
run_test "Validates custom provider" test_validates_custom_provider
run_test "Rejects missing custom provider function" test_rejects_missing_custom_provider_function
run_test "Comment hook enabled by default" test_comment_hook_enabled_by_default
run_test "Comment hook can be disabled" test_comment_hook_can_be_disabled
run_test "Default trigger is '# '" test_default_trigger_is_hash
run_test "Loads provider from config file" test_loads_provider_from_config_file
run_test "Loads API key from config file" test_loads_api_key_from_config_file
run_test "Env var overrides config file" test_env_var_overrides_config_file
run_test "Env API key overrides config file" test_env_api_key_overrides_config_file
run_test "Config file ignores comments and blank lines" test_config_file_ignores_comments_and_blank_lines
run_test "Config file strips surrounding quotes" test_config_file_strips_surrounding_quotes
run_test "Missing config file uses defaults" test_missing_config_file_uses_defaults
run_test "Config file respects XDG_CONFIG_HOME" test_config_file_uses_xdg_config_home
run_test "Config file handles inline comment" test_config_file_inline_comment
run_test "Config file keeps # inside quotes" test_config_file_keeps_hash_inside_quotes
run_test "Config file ignores lines without '='" test_config_file_ignores_lines_without_equals
finish_tests
