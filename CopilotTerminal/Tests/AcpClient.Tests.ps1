Describe 'ACP Client' {
    It 'Should build a valid JSON-RPC initialize message' {
        Set-ItResult -Pending -Because 'module scaffold only'
        # Verify message has jsonrpc:"2.0", method:"initialize", correct params
    }

    It 'Should complete the initialize handshake' {
        Set-ItResult -Pending -Because 'module scaffold only'
        # Mock TCP stream; send initialize, receive response, send initialized notification
    }

    It 'Should create a session with correct capabilities' {
        Set-ItResult -Pending -Because 'module scaffold only'
        # Verify createSession request includes agent name and version
    }

    It 'Should send a prompt and stream turn updates' {
        Set-ItResult -Pending -Because 'module scaffold only'
        # Mock a turn/update sequence with delta text and verify concatenated output
    }

    It 'Should handle streaming text deltas correctly' {
        Set-ItResult -Pending -Because 'module scaffold only'
        # Verify multiple small text deltas are assembled into final response
    }

    It 'Should request permission for tool calls in Q&A mode' {
        Set-ItResult -Pending -Because 'module scaffold only'
        # When ApproveTools is $false, tool confirmations should be surfaced to user
    }

    It 'Should auto-approve tool calls in agent mode' {
        Set-ItResult -Pending -Because 'module scaffold only'
        # When ApproveTools is $true, tool confirmations should be auto-accepted
    }

    It 'Should recover from connection loss' {
        Set-ItResult -Pending -Because 'module scaffold only'
        # After a dropped TCP connection, next query should reconnect transparently
    }
}
