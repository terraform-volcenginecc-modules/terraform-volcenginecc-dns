# Changelog

## Initial implementation

- Sequence the complete example's AAAA record after other records to mitigate concurrent DNS writes; preserve outputs and migrate existing AAAA state with a moved block.

- Add a public DNS zone and keyed-record module with basic and complete examples.
- Explicit external-zone ownership and externally enabled weighted-routing boundary.
- Bilingual documentation and basic/complete examples.
- Document caller-managed domain registration, NS delegation and externally enabled weighted routing.
- Configure A, AAAA, CNAME, MX, TXT, NS and SRV records with edition-permitted line routing.
