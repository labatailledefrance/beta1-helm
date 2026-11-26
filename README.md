# beta1-helm

Charts Helm de la beta 1 de **La Bataille de France**, publiés en OCI sur `ghcr.io/labatailledefrance/charts` et signés par la CI (cosign sans clé).

| Chart | Contenu |
|---|---|
| `game` | Un monde : serveur (StatefulSet à une réplique, volume local), client (nginx), IngressRoute Traefik (TLS Let's Encrypt, rate limits par adresse IP, en-têtes COOP et COEP), NetworkPolicies (tout fermé sauf depuis Traefik). Images **par digest** uniquement |
| `policies` | Politiques Kyverno : dans le namespace du jeu, un pod n'est admis que si ses images viennent de `ghcr.io/labatailledefrance`, par digest, signées par le workflow `image.yml` de l'organisation |

Une version du chart `game` épingle les deux images par digest : la monter, c'est remettre le monde à zéro (H-01, H-07).

## Installer

```
# 1. Kyverno (une fois par cluster), chart OCI officiel signé.
cosign verify ghcr.io/kyverno/charts/kyverno:3.9.2 \
  --certificate-identity-regexp '^https://github\.com/kyverno/kyverno/' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
helm install kyverno oci://ghcr.io/kyverno/charts/kyverno --version 3.9.2 -n kyverno --create-namespace

# 2. Nos charts : vérifier la signature, puis installer par version.
ID='^https://github\.com/labatailledefrance/\.github/\.github/workflows/chart\.yml@.+$'
for c in policies game; do
  cosign verify ghcr.io/labatailledefrance/charts/$c:0.1.0 \
    --certificate-identity-regexp "$ID" --certificate-oidc-issuer https://token.actions.githubusercontent.com
done
helm install policies oci://ghcr.io/labatailledefrance/charts/policies --version 0.1.0
helm install game oci://ghcr.io/labatailledefrance/charts/game --version 0.1.0 \
  -n labatailledefrance --create-namespace \
  --set server.image.digest=sha256:… --set client.image.digest=sha256:…
```

## Vérifier en local

```
helm lint --strict charts/game -f charts/game/ci/test-values.yaml
helm template game charts/game -f charts/game/ci/test-values.yaml | kubeconform -strict -ignore-missing-schemas
```

Contribution : [CONTRIBUTING.md](https://github.com/labatailledefrance/.github/blob/main/CONTRIBUTING.md). Licence : AGPL-3.0-or-later.
