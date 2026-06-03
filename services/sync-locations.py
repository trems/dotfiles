#!/usr/bin/env python3
import os
import re
import json
import codecs
import configparser

INI_PATH = os.path.expanduser("~/Library/Application Support/redshieldvpn/Red Shield VPN/ini/Red Shield VPN.ini")
JSON_PATH = os.path.join(os.path.dirname(__file__), "redshield-locations.json")

def main():
    if not os.path.exists(INI_PATH):
        print(f"Error: Red Shield VPN INI file not found at {INI_PATH}")
        return

    # Read and parse INI
    config = configparser.ConfigParser()
    config.read(INI_PATH)
    
    if "hosts" not in config or "hosts" not in config["hosts"]:
        print("Error: Could not find [hosts] section in INI file.")
        return

    hosts_val = config.get("hosts", "hosts")
    if hosts_val.startswith("\"") and hosts_val.endswith("\""):
        hosts_val = hosts_val[1:-1]

    # Decode escape sequences
    unescaped_bytes = codecs.escape_decode(bytes(hosts_val, "utf-8"))[0]
    unescaped_str = unescaped_bytes.decode("utf-8", "ignore")
    decoded_str = re.sub(r"\\x([0-9a-fA-F]+)", lambda m: chr(int(m.group(1), 16)), unescaped_str)
    final_str = decoded_str.encode("utf-16", "surrogatepass").decode("utf-16")
    
    data = json.loads(final_str)
    locations = data.get("locations", [])
    awg_port = data.get("awg_port", 3478)

    # Load existing locations if present
    existing_locations = {}
    if os.path.exists(JSON_PATH):
        try:
            with open(JSON_PATH, "r") as f:
                existing_locations = json.load(f)
        except Exception as e:
            print(f"Warning: Could not parse existing JSON ({e}). Re-creating.")

    new_locations = {}
    for loc in locations:
        name = loc.get("name", "")
        code = loc.get("code", "")
        hosts = loc.get("hosts", [])
        
        if not name or not hosts:
            continue

        # Clean name to be a valid Nix key
        clean_name = name.split("|")[0].strip().lower()
        clean_name = re.sub(r"[^a-z0-9_-]", "-", clean_name)
        clean_name = re.sub(r"-+", "-", clean_name).strip("-")
        
        hostname = f"rsv-{clean_name}"
        endpoint = f"{hosts[0]}:{awg_port}"
        
        # Determine bypassRu status: preserve existing if present, otherwise default to True
        existing_loc = existing_locations.get(clean_name, {})
        if "bypassRu" in existing_loc:
            bypass_ru = existing_loc["bypassRu"]
        else:
            bypass_ru = True

        new_locations[clean_name] = {
            "hostname": hostname,
            "endpoint": endpoint,
            "bypassRu": bypass_ru
        }

    # Save to JSON
    with open(JSON_PATH, "w") as f:
        json.dump(new_locations, f, indent=2, sort_keys=True)

    print(f"Successfully synchronized {len(new_locations)} locations to {JSON_PATH}")

if __name__ == "__main__":
    main()
