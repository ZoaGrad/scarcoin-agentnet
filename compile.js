const fs = require('fs');
const path = require('path');
const solc = require('solc');

// Define paths
const buildDir = path.resolve(__dirname, 'build');
const scarCoinPath = path.resolve(__dirname, 'contracts', 'core', 'ScarCoin.sol');
const ritualRegistryPath = path.resolve(__dirname, 'contracts', 'rituals', 'RitualRegistry.sol');

// Create build directory if it doesn't exist
if (!fs.existsSync(buildDir)) {
    fs.mkdirSync(buildDir);
}

// Read contract sources
const scarCoinSource = fs.readFileSync(scarCoinPath, 'utf8');
const ritualRegistrySource = fs.readFileSync(ritualRegistryPath, 'utf8');

// The solc compiler needs to resolve imports from OpenZeppelin.
// This callback function reads files from node_modules.
function findImports(importPath) {
    try {
        // Attempt to resolve the import path from the node_modules directory
        const fullPath = require.resolve(importPath, { paths: [path.join(__dirname, 'node_modules')] });
        return { contents: fs.readFileSync(fullPath, 'utf8') };
    } catch (e) {
        // Fallback for relative paths or other structures
        const directPath = path.resolve(__dirname, 'node_modules', importPath);
        if (fs.existsSync(directPath)) {
            return { contents: fs.readFileSync(directPath, 'utf8') };
        }
        return { error: 'File not found: ' + importPath };
    }
}

const input = {
    language: 'Solidity',
    sources: {
        'contracts/core/ScarCoin.sol': {
            content: scarCoinSource
        },
        'contracts/rituals/RitualRegistry.sol': {
            content: ritualRegistrySource
        }
    },
    settings: {
        outputSelection: {
            '*': {
                '*': ['abi']
            }
        }
    }
};

const output = JSON.parse(solc.compile(JSON.stringify(input), { import: findImports }));

let compilationFailed = false;
if (output.errors) {
    for (const error of output.errors) {
        if (error.severity === 'error') {
            console.error(error.formattedMessage);
            compilationFailed = true;
        } else {
            console.warn(error.formattedMessage);
        }
    }
}

if (compilationFailed) {
    console.error('\nCompilation failed.');
    process.exit(1);
}

if (!output.contracts) {
    console.error('\nCompilation failed: No contracts found in output.');
    process.exit(1);
}

// Extract and write ABIs
const scarCoinAbi = output.contracts['contracts/core/ScarCoin.sol']['ScarCoin'].abi;
fs.writeFileSync(path.resolve(buildDir, 'ScarCoin.abi.json'), JSON.stringify(scarCoinAbi, null, 2));
console.log('Successfully wrote ScarCoin ABI to build/ScarCoin.abi.json');

const ritualRegistryAbi = output.contracts['contracts/rituals/RitualRegistry.sol']['RitualRegistry'].abi;
fs.writeFileSync(path.resolve(buildDir, 'RitualRegistry.abi.json'), JSON.stringify(ritualRegistryAbi, null, 2));
console.log('Successfully wrote RitualRegistry ABI to build/RitualRegistry.abi.json');
