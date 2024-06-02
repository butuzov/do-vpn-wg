# Wireguard Server (On Demand)

1. Generate Dogital Ocean Token
2. Export it to shell
  ```shell
  export DIGITALOCEAN_TOKEN=dop_v1_...
  ```
3. Create `.auto.tfvars`.
  ```shell
  echo "do_token = \"${DIGITALOCEAN_TOKEN}\"" > .auto.tfvars
  ```

4. Check if you have `~/.ssh/id_rsa`, if not run `ssh-keygen -o`
5. Generate Private And Publick Keys to be used by WG
```shell
wg genkey | tee ./configs/client_private_key | wg pubkey | tee ./configs/client_public_key
wg genkey | tee ./configs/server_private_key | wg pubkey | tee ./configs/server_public_key
```

5. Check (just in case) of what images in what locations DO has, using [UI](https://docs.digitalocean.com/reference/api/api-try-it-now/) (look for `sizes` endpoint) or curl `command`

  ```shell
  curl -X 'GET' 'https://api.digitalocean.com/v2/sizes?per_page=100&page=1' \
    -H 'accept: application/json' -H 'Authorization: Bearer ${DIGITALOCEAN_TOKEN}' > sizes.json
  ```
6. Run Terraform

```shell
terraform init -upgrade
terraform plan
terraform apply # (without --auto-approve)
```

7.  __wg0.conf__ can be used for local peer to be connected.
8. Use it (see https://ip.guide/, it's netherlands!)
9. Destroy Your VPN server

  ```shell
  terraform destroy --auto-approve
  ```


P.S.

```shell
# ssh into machine if you need to debug something...
ssh -i ~/.ssh/id_rsa root@IP
```
