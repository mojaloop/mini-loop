import argparse
from pathlib import Path
from ruamel.yaml import YAML

def update_image_tags(directory_path, new_image_tags):
    yaml = YAML()
    path = Path(directory_path)
    for filepath in path.glob("*.yaml"):
        print(f"Processing file: {filepath}")
        updated = False
        with open(filepath) as file:
            data = yaml.load(file)

        # Recursive function to update image tags
        def update_tags(data):
            nonlocal updated
            if isinstance(data, dict):
                for key, value in data.items():
                    if key == "image" and isinstance(value, str) and value.startswith("mojaloop/"):
                        existing_image_tag = value
                        for image_tag in new_image_tags:
                            if image_tag.split(":")[0] in existing_image_tag:
                                updated_value = image_tag
                                data[key] = updated_value
                                updated = True
                                print(f"Updating image tag: {value} -> {updated_value}")
                                break
                    else:
                        update_tags(value)
            elif isinstance(data, list):
                for item in data:
                    update_tags(item)

        update_tags(data)

        if updated:
            with open(filepath, 'w') as file:
                yaml.dump(data, file)
                print(f"File updated: {filepath}")

# Parse command-line arguments
parser = argparse.ArgumentParser(description="Update image tags in YAML files.")
parser.add_argument("directory", help="Directory path containing YAML files")
args = parser.parse_args()

# Example usage:
directory_path = args.directory
new_image_tags = [
    "mojaloop/interop-apis-bc-fspiop-api-svc:0.1.17",
    "mojaloop/accounts-and-balances-bc-builtin-ledger-grpc-svc:0.2.2",
    "mojaloop/accounts-and-balances-bc-coa-grpc-svc:0.2.2",
    "mojaloop/participants-bc-participants-svc:0.1.13",
    "mojaloop/account-lookup-bc-http-oracle-svc:0.1.1",
    "mojaloop/account-lookup-bc-account-lookup-svc:0.1.10",
    "mojaloop/quoting-bc-quoting-svc:0.1.11",
    "mojaloop/transfers-bc-transfers-api-svc:0.2.1",
    "mojaloop/transfers-bc-event-handler-svc:0.2.0",
    "mojaloop/transfers-bc-command-handler-svc:0.2.0",
    "mojaloop/settlements-bc-settlements-api-svc:0.1.3",
    "mojaloop/settlements-bc-event-handler-svc:0.1.2",
    "mojaloop/settlements-bc-command-handler-svc:0.1.3",
    "mojaloop/vnext-admin-ui-svc:0.1.12"
]
update_image_tags(directory_path, new_image_tags)
