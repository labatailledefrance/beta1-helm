# beta1-helm

Charts Helm de la beta 1 de **La Bataille de France**, publiés en OCI sur `ghcr.io/labatailledefrance/charts` et signés par la CI (cosign sans clé).

| Chart | Contenu |
|---|---|
| `game` | Un monde : serveur (StatefulSet à une réplique, volume local), client (nginx), IngressRoute Traefik (TLS Let's Encrypt, rate limits par adresse IP, en-têtes COOP et COEP), NetworkPolicies (tout fermé sauf depuis Traefik). Images **par digest** uniquement |
| `policies` | Politiques Kyverno : dans le namespace du jeu, un pod n'est admis que si ses images viennent de `ghcr.io/labatailledefrance`, par digest, signées par le workflow `image.yml` de l'organisation |

Une version du chart `game` épingle les deux images par digest : la monter, c'est remettre le monde à zéro (H-01, H-07).

## Installer

```
# 1. Kyverno (une fois par cluster), chart durci de dhi.io (Kyverno v1.19.2), par
#    digest. Ses images viennent de dhi.io : secret de tirage dans le namespace.
kubectl create namespace kyverno
kubectl -n kyverno create secret docker-registry dhi --docker-server=dhi.io \
  --docker-username=… --docker-password=…
helm install kyverno oci://dhi.io/kyverno-chart@sha256:30fed4df0eea007811ed0c46176b37a8098cb745038f3a801002d483e72d9cc7 \
  -n kyverno --set 'global.imagePullSecrets[0].name=dhi'   # 3.9.2

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

Tant que les dépôts sont privés, les charts et les images le sont aussi sur ghcr.io : `helm registry login ghcr.io` et `cosign login ghcr.io` avec un jeton qui a `read:packages`, et un secret de tirage dans le cluster (`imagePullSecret`, `images.registryCredentials`).

## Vérifier en local

```
helm lint --strict charts/game -f charts/game/ci/test-values.yaml
helm template game charts/game -f charts/game/ci/test-values.yaml | kubeconform -strict -ignore-missing-schemas
```

Contribution : [CONTRIBUTING.md](https://github.com/labatailledefrance/.github/blob/main/CONTRIBUTING.md). Licence : AGPL-3.0-or-later.
