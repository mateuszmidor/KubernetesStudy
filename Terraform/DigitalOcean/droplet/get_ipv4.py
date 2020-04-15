import sys, json

with open('terraform.tfstate') as f:
    state = json.load(f)
    
dns = state['resources'][0]['instances'][0]['attributes']['ipv4_address']
print(dns)