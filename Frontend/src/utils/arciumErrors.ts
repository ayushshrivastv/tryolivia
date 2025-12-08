/**
 * Olivia: Decentralised Permissionless Prediction Market
 * Copyright (c) 2025 Ayush Srivastava
 *
 * Licensed under the Apache 2.0
 */

/**
 * Arcium-specific error parsing and user-friendly messages
 * This helps users understand what went wrong with their encrypted transactions
 */

export interface ArciumError {
  type: 'arcium' | 'solana' | 'network' | 'unknown';
  code?: string;
  message: string;
  userMessage: string;
  retry: boolean;
  details?: string;
}

/**
 * Parse Solana transaction error and return user-friendly message
 */
export function parseArciumError(error: any): ArciumError {
  // Try to parse JSON string if error is a string
  let parsedError: any = error;
  if (typeof error === 'string') {
    try {
      parsedError = JSON.parse(error);
    } catch {
      // Not JSON, use as-is
      parsedError = error;
    }
  }
  
  // First, check if error is an object with InstructionError format
  // This format: {"InstructionError":[3,"ProgramFailedToComplete"]}
  if (typeof parsedError === 'object' && parsedError !== null) {
    // Check for InstructionError array format
    if (parsedError.InstructionError && Array.isArray(parsedError.InstructionError)) {
      const errorCode = parsedError.InstructionError[1];
      if (errorCode === 'ProgramFailedToComplete' || 
          (typeof errorCode === 'string' && errorCode.includes('FailedToComplete'))) {
        return {
          type: 'arcium',
          code: 'ProgramFailedToComplete',
          message: JSON.stringify(parsedError),
          userMessage: 'The encrypted computation failed to complete. ARX nodes may be unavailable on devnet.',
          retry: true,
          details: 'The Arcium MPC nodes were unable to complete the encrypted computation. ARX (Arcium Runtime eXecution) nodes are required for encrypted computations but may not be available on devnet. Options: 1) Retry later when nodes are available, 2) Use localnet with ARX nodes, or 3) Enable demo mode (NEXT_PUBLIC_DEMO_NO_ARCIUM=true) for testing without encryption.'
        };
      }
    }
    
    // Check JSON string representation for Arcium errors
    const errorJson = JSON.stringify(parsedError);
    if (errorJson.includes('ProgramFailedToComplete') || 
        errorJson.includes('Program failed to complete') ||
        errorJson.includes('failed to complete')) {
      return {
        type: 'arcium',
        code: 'ProgramFailedToComplete',
        message: errorJson,
        userMessage: 'The encrypted computation failed to complete. ARX nodes may be unavailable on devnet.',
        retry: true,
        details: 'The Arcium MPC nodes were unable to complete the encrypted computation. ARX (Arcium Runtime eXecution) nodes are required for encrypted computations but may not be available on devnet. Options: 1) Retry later when nodes are available, 2) Use localnet with ARX nodes, or 3) Enable demo mode (NEXT_PUBLIC_DEMO_NO_ARCIUM=true) for testing without encryption.'
      };
    }
  }
  
  // Convert to string for pattern matching
  const errorString = typeof error === 'string'
    ? error
    : error?.message || JSON.stringify(error);

  // Check for common Arcium MPC errors in string format
  // IMPORTANT: Check these patterns first before generic patterns
  
  // ProgramFailedToComplete can appear in different formats
  if (errorString.includes('ProgramFailedToComplete') || 
      errorString.includes('Program failed to complete') ||
      errorString.includes('failed to complete')) {
    return {
      type: 'arcium',
      code: 'ProgramFailedToComplete',
      message: errorString,
      userMessage: 'The encrypted computation failed to complete. ARX nodes may be unavailable on devnet.',
      retry: true,
      details: 'The Arcium MPC nodes were unable to complete the encrypted computation. ARX (Arcium Runtime eXecution) nodes are required for encrypted computations but may not be available on devnet. Options: 1) Retry later when nodes are available, 2) Use localnet with ARX nodes, or 3) Enable demo mode (NEXT_PUBLIC_DEMO_NO_ARCIUM=true) for testing without encryption.'
    };
  }

  if (errorString.includes('AccountNotInitialized')) {
    return {
      type: 'arcium',
      code: 'AccountNotInitialized',
      message: errorString,
      userMessage: 'Arcium MPC environment is not properly initialized.',
      retry: false,
      details: 'The computation definition or MXE account required for encrypted operations is not initialized. Please contact support.'
    };
  }

  if (errorString.includes('ComputationNotFound')) {
    return {
      type: 'arcium',
      code: 'ComputationNotFound',
      message: errorString,
      userMessage: 'The encrypted computation could not be found.',
      retry: true,
      details: 'The computation may have expired or been lost. Please try submitting your transaction again.'
    };
  }

  if (errorString.includes('InvalidComputationOffset')) {
    return {
      type: 'arcium',
      code: 'InvalidComputationOffset',
      message: errorString,
      userMessage: 'Invalid computation identifier.',
      retry: true,
      details: 'The computation offset is invalid. This is likely a temporary issue - please try again.'
    };
  }

  if (errorString.includes('MXENotFound') || errorString.includes('MXE account not found')) {
    return {
      type: 'arcium',
      code: 'MXENotFound',
      message: errorString,
      userMessage: 'Arcium MPC environment not found.',
      retry: false,
      details: 'The Multi-Party Execution environment required for encrypted predictions is not deployed. Please contact support.'
    };
  }

  if (errorString.includes('ClusterNotFound') || errorString.includes('cluster account')) {
    return {
      type: 'arcium',
      code: 'ClusterNotFound',
      message: errorString,
      userMessage: 'Arcium MPC cluster is not available.',
      retry: true,
      details: 'The Arcium computation cluster is not responding. Please try again shortly.'
    };
  }

  // Common Solana errors
  if (errorString.includes('InsufficientFunds') || errorString.includes('insufficient funds')) {
    return {
      type: 'solana',
      code: 'InsufficientFunds',
      message: errorString,
      userMessage: 'Insufficient SOL balance to complete transaction.',
      retry: false,
      details: 'You need more SOL to cover transaction fees and rent. Please add funds to your wallet.'
    };
  }

  if (errorString.includes('BlockhashNotFound')) {
    return {
      type: 'network',
      code: 'BlockhashNotFound',
      message: errorString,
      userMessage: 'Network congestion - transaction expired.',
      retry: true,
      details: 'The transaction took too long to process and the blockhash expired. Please try again.'
    };
  }

  if (errorString.includes('Transaction simulation failed')) {
    return {
      type: 'solana',
      code: 'SimulationFailed',
      message: errorString,
      userMessage: 'Transaction would fail if submitted.',
      retry: false,
      details: extractSimulationError(errorString)
    };
  }

  if (errorString.includes('timeout') || errorString.includes('timed out')) {
    return {
      type: 'network',
      code: 'Timeout',
      message: errorString,
      userMessage: 'Network timeout - transaction is taking longer than expected.',
      retry: true,
      details: 'Arcium MPC computations can take 1-3 minutes. The transaction may still succeed - check the explorer.'
    };
  }

  if (errorString.includes('429') || errorString.includes('rate limit')) {
    return {
      type: 'network',
      code: 'RateLimit',
      message: errorString,
      userMessage: 'Too many requests - please wait a moment.',
      retry: true,
      details: 'The RPC endpoint is rate limiting requests. Please wait 10-30 seconds and try again.'
    };
  }

  // Generic network errors - but NOT if it's actually an Arcium error
  // Only treat as network error if it's truly a connection issue
  if ((errorString.includes('fetch') || errorString.includes('ECONNREFUSED') || 
       errorString.includes('ECONNRESET')) && 
      !errorString.includes('ProgramFailedToComplete') &&
      !errorString.includes('computation') &&
      !errorString.includes('MPC')) {
    return {
      type: 'network',
      code: 'NetworkError',
      message: errorString,
      userMessage: 'Network connection issue.',
      retry: true,
      details: 'Unable to connect to the Solana network. Please check your internet connection and try again.'
    };
  }
  
  // If error string contains "network" but is about Arcium computation, it's an Arcium error
  if (errorString.includes('network') && 
      (errorString.includes('computation') || errorString.includes('MPC') || 
       errorString.includes('Arcium') || errorString.includes('encrypted'))) {
    return {
      type: 'arcium',
      code: 'ComputationTimeout',
      message: errorString,
      userMessage: 'The encrypted computation timed out or failed.',
      retry: true,
      details: 'The Arcium MPC computation did not complete in time. This can happen if ARX nodes are slow or unavailable. Please try again.'
    };
  }

  // Unknown error
  return {
    type: 'unknown',
    message: errorString,
    userMessage: 'An unexpected error occurred.',
    retry: true,
    details: errorString.length > 200 ? errorString.substring(0, 200) + '...' : errorString
  };
}

/**
 * Extract detailed error from simulation failure
 */
function extractSimulationError(errorString: string): string {
  // Try to extract the actual error from simulation logs
  const match = errorString.match(/Program log: (.+)/);
  if (match && match[1]) {
    return match[1];
  }

  // Try to extract instruction error
  const instrMatch = errorString.match(/InstructionError\[(\d+),\s*(.+)\]/);
  if (instrMatch && instrMatch[2]) {
    return `Instruction ${instrMatch[1]} failed: ${instrMatch[2]}`;
  }

  return 'The transaction would fail if submitted. Check the console for details.';
}

/**
 * Get user-friendly retry suggestion
 */
export function getRetryMessage(error: ArciumError): string {
  if (!error.retry) {
    return 'This issue requires intervention. Please check the error details or contact support.';
  }

  switch (error.type) {
    case 'arcium':
      if (error.code === 'ProgramFailedToComplete') {
        return 'ARX nodes may be temporarily unavailable on devnet. Consider: 1) Using localnet with ARX nodes for development, or 2) Enabling demo mode in .env.local (NEXT_PUBLIC_DEMO_NO_ARCIUM=true) to test without encryption.';
      }
      return 'Arcium MPC computations can be slow during high network activity. Please wait 30 seconds and try again.';
    case 'network':
      return 'Network issues are usually temporary. Please try again in a few moments.';
    case 'solana':
      return 'Please check the error details and try again.';
    default:
      return 'Please try again. If the issue persists, contact support.';
  }
}

/**
 * Format error for console logging with helpful context
 */
export function logArciumError(error: ArciumError, context?: string): void {
  const prefix = context ? `[${context}]` : '[Arcium Error]';

  console.error(`${prefix} ${error.type.toUpperCase()}: ${error.userMessage}`);
  console.error(`${prefix} Details:`, error.details);
  console.error(`${prefix} Retry suggested:`, error.retry);
  console.error(`${prefix} Raw error:`, error.message);
}
