import { existsSync, readFileSync, writeFileSync, mkdirSync, copyFileSync } from "node:fs";
import { join, dirname } from "node:path";
import { homedir } from "node:os";
import { fileURLToPath } from "node:url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

export async function runSetup() {
  const home = homedir();
  console.log("\n🐿️  walnut setup\n");

  const configured: string[] = [];
  const skipped: string[] = [];

  // 1. Detect and configure Hermes
  const hermesConfig = join(home, ".hermes", "config.yaml");
  if (existsSync(hermesConfig)) {
    const content = readFileSync(hermesConfig, "utf-8");
    if (content.includes("walnut-mcp") || content.includes("@lock-in-lab/walnut")) {
      skipped.push("Hermes (already configured)");
    } else {
      // Append MCP server config
      const addition = `\n# Walnut context management\n  walnut:\n    command: "npx"\n    args: ["@lock-in-lab/walnut"]\n`;
      if (content.includes("mcp_servers:")) {
        // Add under existing mcp_servers block
        const updated = content.replace("mcp_servers:", "mcp_servers:" + addition);
        writeFileSync(hermesConfig, updated);
      } else {
        // Add new mcp_servers block
        writeFileSync(hermesConfig, content + "\nmcp_servers:" + addition);
      }
      // Copy Hermes skill
      const skillDir = join(home, ".hermes", "skills", "walnuts");
      const skillSrc = join(__dirname, "..", "skills", "walnuts", "SKILL.md");
      if (existsSync(skillSrc)) {
        mkdirSync(skillDir, { recursive: true });
        copyFileSync(skillSrc, join(skillDir, "SKILL.md"));
      }
      configured.push("Hermes (config.yaml + skill copied)");
    }
  }

  // 2. Detect and configure Claude Desktop
  const claudeDesktopConfig = join(home, "Library", "Application Support", "Claude", "claude_desktop_config.json");
  if (existsSync(claudeDesktopConfig)) {
    try {
      const content = JSON.parse(readFileSync(claudeDesktopConfig, "utf-8"));
      if (content.mcpServers?.walnut) {
        skipped.push("Claude Desktop (already configured)");
      } else {
        content.mcpServers = content.mcpServers || {};
        content.mcpServers.walnut = {
          command: "npx",
          args: ["@lock-in-lab/walnut"]
        };
        writeFileSync(claudeDesktopConfig, JSON.stringify(content, null, 2));
        configured.push("Claude Desktop");
      }
    } catch {
      skipped.push("Claude Desktop (config parse error)");
    }
  }

  // 3. Detect and configure Cursor
  const cursorConfig = join(home, ".cursor", "mcp.json");
  if (existsSync(cursorConfig) || existsSync(join(home, ".cursor"))) {
    try {
      const content = existsSync(cursorConfig)
        ? JSON.parse(readFileSync(cursorConfig, "utf-8"))
        : { mcpServers: {} };
      if (content.mcpServers?.walnut) {
        skipped.push("Cursor (already configured)");
      } else {
        content.mcpServers = content.mcpServers || {};
        content.mcpServers.walnut = {
          command: "npx",
          args: ["@lock-in-lab/walnut"]
        };
        mkdirSync(join(home, ".cursor"), { recursive: true });
        writeFileSync(cursorConfig, JSON.stringify(content, null, 2));
        configured.push("Cursor");
      }
    } catch {
      skipped.push("Cursor (config parse error)");
    }
  }

  // 4. Detect and configure Windsurf
  const windsurfConfig = join(home, ".codeium", "windsurf", "mcp_config.json");
  if (existsSync(join(home, ".codeium", "windsurf")) || existsSync(windsurfConfig)) {
    try {
      const content = existsSync(windsurfConfig)
        ? JSON.parse(readFileSync(windsurfConfig, "utf-8"))
        : { mcpServers: {} };
      if (content.mcpServers?.walnut) {
        skipped.push("Windsurf (already configured)");
      } else {
        content.mcpServers = content.mcpServers || {};
        content.mcpServers.walnut = {
          command: "npx",
          args: ["@lock-in-lab/walnut"]
        };
        mkdirSync(join(home, ".codeium", "windsurf"), { recursive: true });
        writeFileSync(windsurfConfig, JSON.stringify(content, null, 2));
        configured.push("Windsurf");
      }
    } catch {
      skipped.push("Windsurf (config parse error)");
    }
  }

  // 5. Scaffold world if it doesn't exist
  const worldPath = join(home, "world");
  if (!existsSync(worldPath)) {
    const domains = ["01_Archive", "02_Life", "03_Inputs", "04_Ventures", "05_Experiments"];
    for (const d of domains) {
      mkdirSync(join(worldPath, d), { recursive: true });
    }
    mkdirSync(join(worldPath, ".walnut"), { recursive: true });
    mkdirSync(join(worldPath, "02_Life", "people"), { recursive: true });
    configured.push("World scaffolded at ~/world/");
  } else {
    skipped.push("World (already exists at ~/world/)");
  }

  // Print summary
  console.log("  Configured:");
  if (configured.length === 0) {
    console.log("    (nothing new — everything was already set up)");
  } else {
    for (const c of configured) {
      console.log(`    ✓ ${c}`);
    }
  }

  if (skipped.length > 0) {
    console.log("\n  Skipped:");
    for (const s of skipped) {
      console.log(`    · ${s}`);
    }
  }

  // Detect what wasn't found
  const notFound: string[] = [];
  if (!existsSync(hermesConfig)) notFound.push("Hermes (~/.hermes/config.yaml)");
  if (!existsSync(claudeDesktopConfig)) notFound.push("Claude Desktop");
  if (!existsSync(join(home, ".cursor"))) notFound.push("Cursor");
  if (!existsSync(join(home, ".codeium", "windsurf"))) notFound.push("Windsurf");

  if (notFound.length > 0) {
    console.log("\n  Not detected:");
    for (const n of notFound) {
      console.log(`    - ${n}`);
    }
  }

  console.log("\n  Done. Your agents now have structured context.\n");
  console.log("  Next: open your AI tool and say \"what are my projects?\"\n");
}
