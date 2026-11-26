# beta1-helm

Charts Helm de la beta 1 de **La Bataille de France**, publiés en OCI sur `ghcr.io/labatailledefrance/charts` et signés par la CI (cosign sans clé).

| Chart | Contenu |
|---|---|
| `game` | Un monde : serveur (StatefulSet à une réplique, volume local), client (nginx), IngressRoute Traefik (TLS Let's Encrypt, rate limits par adresse IP, en-têtes COOP et COEP), NetworkPolicies (tout fermé sauf depuis Traefik). Images **par digest** uniquement |

Une version du chart `game` épingle les deux images par digest : la monter, c'est remettre le monde à zéro (H-01, H-07).

## Installer

Le cluster n'a pas de contrôle d'admission : la signature du chart et des images se vérifie **avant** l'installation.

```
ISSUER=https://token.actions.githubusercontent.com
CHART_ID='^https://github\.com/labatailledefrance/\.github/\.github/workflows/chart\.yml@.+$'
IMAGE_ID='^https://github\.com/labatailledefrance/\.github/\.github/workflows/image\.yml@.+$'
SERVER=sha256:…   # digests publiés par la CI de beta1-server et beta1-client
CLIENT=sha256:…

cosign verify ghcr.io/labatailledefrance/charts/game:0.1.0 --certificate-identity-regexp "$CHART_ID" --certificate-oidc-issuer "$ISSUER"
cosign verify ghcr.io/labatailledefrance/beta1-server@$SERVER --certificate-identity-regexp "$IMAGE_ID" --certificate-oidc-issuer "$ISSUER"
cosign verify ghcr.io/labatailledefrance/beta1-client@$CLIENT --certificate-identity-regexp "$IMAGE_ID" --certificate-oidc-issuer "$ISSUER"

helm install game oci://ghcr.io/labatailledefrance/charts/game --version 0.1.0 \
  -n labatailledefrance --create-namespace \
  --set server.image.digest=$SERVER --set client.image.digest=$CLIENT
```

Tant que les dépôts sont privés, les charts et les images le sont aussi sur ghcr.io : `helm registry login ghcr.io` et `cosign login ghcr.io` avec un jeton qui a `read:packages`, et un secret de tirage dans le cluster (`imagePullSecret`).

## Vérifier en local

```
helm lint --strict charts/game -f charts/game/ci/test-values.yaml
helm template game charts/game -f charts/game/ci/test-values.yaml | kubeconform -strict -ignore-missing-schemas
```

Contribution : [CONTRIBUTING.md](https://github.com/labatailledefrance/.github/blob/main/CONTRIBUTING.md). Licence : AGPL-3.0-or-later.
