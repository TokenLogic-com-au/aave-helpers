const {
  createPublicClient,
  createWalletClient,
  http,
  parseAbi,
  decodeEventLog,
} = require("viem");
const { privateKeyToAccount } = require("viem/accounts");
const {
  mainnet,
  optimism,
  arbitrum,
  polygon,
  avalanche,
  base,
  linea,
} = require("viem/chains");

// CCTP Domain IDs (from Circle docs)
const CCTP_DOMAINS = {
  1: 0, // Ethereum Mainnet
  10: 2, // Optimism
  42161: 3, // Arbitrum
  137: 7, // Polygon
  43114: 1, // Avalanche
  8453: 6, // Base
  59144: 11, // Linea
  130: 12, // Codex
  146: 13, // Sonic
  480: 14, // World Chain
  1301: 15, // Unichain Testnet
  534352: 16, // Sei
  56: 17, // BNB Smart Chain
  50: 18, // XDC
  999: 19, // HyperEVM
  57073: 21, // Ink
  98866: 22, // Plume
};

// Chain ID to viem chain mapping
const CHAIN_CONFIG = {
  1: mainnet,
  10: optimism,
  42161: arbitrum,
  137: polygon,
  43114: avalanche,
  8453: base,
  59144: linea,
};

// Circle Attestation API hosts
const ATTESTATION_API = {
  mainnet: "https://iris-api.circle.com",
  testnet: "https://iris-api-sandbox.circle.com",
};

// MessageTransmitterV2 ABI (minimal for receiveMessage)
const MESSAGE_TRANSMITTER_V2_ABI = parseAbi([
  "function receiveMessage(bytes message, bytes attestation) external returns (bool success)",
  "function usedNonces(bytes32 nonce) external view returns (uint256)",
]);

// AaveCctpBridge Bridge event ABI
const BRIDGE_EVENT_ABI = parseAbi([
  "event Bridge(address indexed token, uint32 indexed destinationDomain, address indexed receiver, uint256 amount, uint64 nonce, uint8 speed)",
]);

// MessageTransmitterV2 contract addresses (mainnet)
// Source: https://developers.circle.com/cctp/evm-smart-contracts
const MESSAGE_TRANSMITTER_V2_ADDRESSES = {
  0: "0x81D40F21F12A8F0E3252Bccb954D722d4c464B64", // Ethereum
  1: "0x81D40F21F12A8F0E3252Bccb954D722d4c464B64", // Avalanche
  2: "0x81D40F21F12A8F0E3252Bccb954D722d4c464B64", // Optimism
  3: "0x81D40F21F12A8F0E3252Bccb954D722d4c464B64", // Arbitrum
  6: "0x81D40F21F12A8F0E3252Bccb954D722d4c464B64", // Base
  7: "0x81D40F21F12A8F0E3252Bccb954D722d4c464B64", // Polygon
  10: "0x81D40F21F12A8F0E3252Bccb954D722d4c464B64", // Unichain
  11: "0x81D40F21F12A8F0E3252Bccb954D722d4c464B64", // Linea
};

class CctpRelayer {
  constructor(config) {
    this.sourceClient = createPublicClient({
      chain: CHAIN_CONFIG[config.sourceChainId] || { id: config.sourceChainId },
      transport: http(config.sourceRpcUrl),
    });

    this.destPublicClient = createPublicClient({
      chain: CHAIN_CONFIG[config.destChainId] || { id: config.destChainId },
      transport: http(config.destRpcUrl),
    });

    const account = privateKeyToAccount(config.privateKey);
    this.destWalletClient = createWalletClient({
      account,
      chain: CHAIN_CONFIG[config.destChainId] || { id: config.destChainId },
      transport: http(config.destRpcUrl),
    });

    this.account = account;
    this.attestationApiHost = config.isTestnet
      ? ATTESTATION_API.testnet
      : ATTESTATION_API.mainnet;
    this.sourceDomain = config.sourceDomain;
    this.destDomain = config.destDomain;
    this.pollIntervalMs = config.pollIntervalMs || 5000;
    this.maxRetries = config.maxRetries || 60;
  }

  /**
   * Fetches attestation from Circle's API
   * @param {string} txHash - The burn transaction hash
   * @returns {Promise<{message: string, attestation: string, alreadyReceived: boolean}>}
   */
  async fetchAttestation(txHash) {
    const url = `${this.attestationApiHost}/v2/messages/${this.sourceDomain}?transactionHash=${txHash}`;

    console.log(`Fetching attestation from: ${url}`);

    let retries = 0;
    while (retries < this.maxRetries) {
      try {
        const response = await fetch(url);

        if (!response.ok) {
          throw new Error(`API returned status ${response.status}`);
        }

        const data = await response.json();

        if (data.messages && data.messages.length > 0) {
          const msg = data.messages[0];

          if (msg.status === "complete" && msg.attestation) {
            console.log(`Attestation received for nonce: ${msg.eventNonce}`);

            // Check if already received on destination chain
            const alreadyReceived = await this.isNonceUsed(msg.eventNonce);

            return {
              message: msg.message,
              attestation: msg.attestation,
              nonce: msg.eventNonce,
              decodedMessage: msg.decodedMessage,
              alreadyReceived,
            };
          }

          console.log(
            `Attestation status: ${msg.status}, waiting... (${retries + 1}/${this.maxRetries})`
          );
        } else {
          console.log(
            `No messages found yet, waiting... (${retries + 1}/${this.maxRetries})`
          );
        }
      } catch (error) {
        console.error(`Error fetching attestation: ${error.message}`);
      }

      await this.sleep(this.pollIntervalMs);
      retries++;
    }

    throw new Error(
      `Failed to get attestation after ${this.maxRetries} retries`
    );
  }

  /**
   * Check if a nonce has already been used on the destination chain
   * @param {string} nonce - The message nonce
   * @returns {Promise<boolean>}
   */
  async isNonceUsed(nonce) {
    const transmitterAddress = MESSAGE_TRANSMITTER_V2_ADDRESSES[this.destDomain];

    if (!transmitterAddress) {
      console.log(`  No transmitter address for domain ${this.destDomain}`);
      return false;
    }

    try {
      console.log(`  Checking if nonce ${nonce} is used on ${transmitterAddress}...`);
      const usedNonce = await this.destPublicClient.readContract({
        address: transmitterAddress,
        abi: MESSAGE_TRANSMITTER_V2_ABI,
        functionName: "usedNonces",
        args: [nonce],
      });

      console.log(`  usedNonces result: ${usedNonce}`);
      // If usedNonces returns non-zero, the nonce has been used
      return usedNonce > 0n;
    } catch (error) {
      console.error(`  Error checking nonce: ${error.message}`);
      return false;
    }
  }

  /**
   * Calls receiveMessage on the destination chain
   * @param {string} message - The message bytes from attestation API
   * @param {string} attestation - The attestation signature
   * @param {string} nonce - The message nonce for checking if already used
   * @returns {Promise<{receipt: object|null, alreadyReceived: boolean}>}
   */
  async receiveMessage(message, attestation, nonce) {
    const transmitterAddress = MESSAGE_TRANSMITTER_V2_ADDRESSES[this.destDomain];

    if (!transmitterAddress) {
      throw new Error(
        `Unknown MessageTransmitterV2 address for domain ${this.destDomain}`
      );
    }

    console.log(`Calling receiveMessage on ${transmitterAddress}...`);

    try {
      const { request } = await this.destPublicClient.simulateContract({
        address: transmitterAddress,
        abi: MESSAGE_TRANSMITTER_V2_ABI,
        functionName: "receiveMessage",
        args: [message, attestation],
        account: this.account,
      });

      const hash = await this.destWalletClient.writeContract(request);
      console.log(`Transaction submitted: ${hash}`);

      const receipt = await this.destPublicClient.waitForTransactionReceipt({
        hash,
      });
      console.log(`Transaction confirmed in block ${receipt.blockNumber}`);

      return { receipt, alreadyReceived: false };
    } catch (error) {
      // Check if the error is because the nonce was already used
      const isNonceUsed = await this.isNonceUsed(nonce);
      if (isNonceUsed) {
        console.log(`\nMessage already received on destination chain (nonce used).`);
        return { receipt: null, alreadyReceived: true };
      }
      // Re-throw if it's a different error
      throw error;
    }
  }

  /**
   * Complete a CCTP transfer by fetching attestation and calling receiveMessage
   * @param {string} burnTxHash - The burn transaction hash on source chain
   * @returns {Promise<{attestation: object, receipt: object|null}>}
   */
  async completeTransfer(burnTxHash) {
    console.log(`\nCompleting CCTP transfer for tx: ${burnTxHash}`);
    console.log(
      `Source domain: ${this.sourceDomain}, Dest domain: ${this.destDomain}`
    );

    // Step 1: Fetch attestation
    console.log("\n[Step 1] Fetching attestation from Circle API...");
    const attestationData = await this.fetchAttestation(burnTxHash);

    console.log("\nAttestation details:");
    console.log(`  Nonce: ${attestationData.nonce}`);
    if (attestationData.decodedMessage) {
      const decoded = attestationData.decodedMessage;
      console.log(`  Amount: ${decoded.decodedMessageBody?.amount}`);
      console.log(`  Recipient: ${decoded.decodedMessageBody?.mintRecipient}`);
    }

    // Check if already received on destination chain (pre-check)
    if (attestationData.alreadyReceived) {
      console.log("\nTransfer already completed on destination chain!");
      console.log("  Nonce has been used - skipping receiveMessage call.");
      return { attestation: attestationData, receipt: null };
    }

    // Step 2: Call receiveMessage on destination
    console.log("\n[Step 2] Submitting receiveMessage on destination chain...");
    const result = await this.receiveMessage(
      attestationData.message,
      attestationData.attestation,
      attestationData.nonce
    );

    if (result.alreadyReceived) {
      console.log("\nTransfer was already completed on destination chain!");
      return { attestation: attestationData, receipt: null };
    }

    console.log("\nTransfer completed successfully!");
    console.log(`  Destination tx: ${result.receipt.transactionHash}`);

    return { attestation: attestationData, receipt: result.receipt };
  }

  /**
   * Watch for Bridge events and automatically relay them
   * @param {string} bridgeAddress - AaveCctpBridge contract address
   */
  async watchAndRelay(bridgeAddress) {
    console.log(`\nWatching for Bridge events on ${bridgeAddress}...`);

    const unwatch = this.sourceClient.watchEvent({
      address: bridgeAddress,
      event: BRIDGE_EVENT_ABI[0],
      onLogs: async (logs) => {
        for (const log of logs) {
          try {
            const decoded = decodeEventLog({
              abi: BRIDGE_EVENT_ABI,
              data: log.data,
              topics: log.topics,
            });

            console.log(`\nBridge event detected!`);
            console.log(`  Token: ${decoded.args.token}`);
            console.log(`  Destination: ${decoded.args.destinationDomain}`);
            console.log(`  Receiver: ${decoded.args.receiver}`);
            console.log(`  Amount: ${decoded.args.amount}`);
            console.log(`  Nonce: ${decoded.args.nonce}`);
            console.log(
              `  Speed: ${decoded.args.speed === 0 ? "Fast" : "Standard"}`
            );

            await this.completeTransfer(log.transactionHash);
          } catch (error) {
            console.error(`Error processing Bridge event: ${error.message}`);
          }
        }
      },
    });

    console.log("Relayer is running. Press Ctrl+C to stop.");

    // Keep the process alive
    process.on("SIGINT", () => {
      console.log("\nStopping relayer...");
      unwatch();
      process.exit(0);
    });

    // Keep running indefinitely
    await new Promise(() => {});
  }

  sleep(ms) {
    return new Promise((resolve) => setTimeout(resolve, ms));
  }
}

/**
 * Get CCTP domain from chain ID
 */
function getDomainFromChainId(chainId) {
  const domain = CCTP_DOMAINS[chainId];
  if (domain === undefined) {
    throw new Error(`Unknown chain ID: ${chainId}`);
  }
  return domain;
}

/**
 * Parse command line arguments
 */
function parseArgs() {
  const args = process.argv.slice(2);
  const parsed = {};

  for (let i = 0; i < args.length; i += 2) {
    const key = args[i].replace("--", "");
    const value = args[i + 1];
    parsed[key] = value;
  }

  return parsed;
}

/**
 * Main entry point
 */
async function main() {
  const args = parseArgs();

  // Validate required environment variables
  if (!process.env.PRIVATE_KEY) {
    throw new Error("PRIVATE_KEY environment variable is required");
  }
  if (!process.env.SOURCE_RPC_URL) {
    throw new Error("SOURCE_RPC_URL environment variable is required");
  }
  if (!process.env.DEST_RPC_URL) {
    throw new Error("DEST_RPC_URL environment variable is required");
  }

  const sourceChainId = parseInt(args.source);
  const destChainId = parseInt(args.dest);

  if (!sourceChainId || !destChainId) {
    throw new Error("--source and --dest chain IDs are required");
  }

  // Ensure private key has 0x prefix
  let privateKey = process.env.PRIVATE_KEY;
  if (!privateKey.startsWith("0x")) {
    privateKey = `0x${privateKey}`;
  }

  const config = {
    privateKey,
    sourceRpcUrl: process.env.SOURCE_RPC_URL,
    destRpcUrl: process.env.DEST_RPC_URL,
    sourceChainId,
    destChainId,
    sourceDomain: getDomainFromChainId(sourceChainId),
    destDomain: getDomainFromChainId(destChainId),
    isTestnet: args.testnet === "true",
    pollIntervalMs: parseInt(args.interval) || 5000,
    maxRetries: parseInt(args.retries) || 60,
  };

  const relayer = new CctpRelayer(config);

  if (args.tx) {
    // Complete a specific transfer
    await relayer.completeTransfer(args.tx);
  } else if (args.watch) {
    // Watch for events and relay automatically
    await relayer.watchAndRelay(args.watch);
  } else {
    console.log("CCTP V2 Relayer - See README.md for usage instructions");
  }
}

main().catch((error) => {
  console.error("Error:", error.message);
  process.exit(1);
});

module.exports = { CctpRelayer, getDomainFromChainId, CCTP_DOMAINS };
