from starknet_py.hash.utils import message_signature

r, s = message_signature(msg_hash=0x1, priv_key=0x2f50fee500edfc513542db280b9ff4a3e37a13309d8a24316b190ccaa83b94f)

print(f"{hex(r)} {hex(s)}")
