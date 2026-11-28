# beta1-helm

Charts Helm de la beta 1 de **La Bataille de France**, publiés en OCI sur `ghcr.io/labatailledefrance/charts` et signés par la CI (cosign sans clé).

| Chart | Contenu |
|---|---|
| `game` | Un monde : serveur (StatefulSet à une réplique, volume local), client (nginx), données (Jobs `datachain` et `assets`, PVC gardées, serveur de données nginx), IngressRoute Traefik (TLS Let's Encrypt, rate limits par adresse IP, en-têtes COOP et COEP), NetworkPolicies (tout fermé sauf depuis Traefik ; seuls les Jobs sortent, en 443). Images **par digest** uniquement |

Une version du chart `game` épingle les images par digest : la monter, c'est remettre le monde à zéro (H-01, H-07).

## Données (H-06)

Les tiles et les assets sont des **publications adressées par leurs entrées** ([H-06](https://github.com/labatailledefrance/documentation/blob/main/OPEN-PROBLEMS.md#h-06--diffusion-des-tiles)) : leur identifiant est un hash du digest de l'image qui les produit (et des zones, pour les tiles). Le chart connaît donc le dossier à servir avant qu'il existe.

| Ressource | Rôle |
|---|---|
| PVC `sources`, `tiles`, `assets` | gardées à la désinstallation (`helm.sh/resource-policy: keep`) : régénérer ne retélécharge rien |
| Job `datachain-…` | `datachain` : sources IGN et INSEE → `tiles/<id>/` ; reprise après interruption |
| Job `assets-…` | `assets publier` : téléchargement et conversion (Blender) → `assets/publications/<id>/` |
| Deployment `donnees` | nginx (image du client) : `/tiles/<id>/` et `/assets/<id>/` en lecture seule, immuables (`Cache-Control: immutable`, plages HTTP) ; `/publications.json` donne les deux identifiants au client |

Les Jobs ne sont pas des hooks Helm : ils tournent à chaque installation ou mise à jour et sortent aussitôt si leur publication est complète. Le serveur de données et le serveur de jeu attendent, dans un `initContainer`, le marqueur `COMPLET` de leurs publications : à la première installation, le jeu n'est joignable qu'une fois les tiles produites. Seuls les Jobs sortent du cluster : DNS, puis 443 vers Internet (réseaux privés exclus).

`datachain.zones` limite la chaîne à quelques départements (`[D029, FRANCE]`) ; vide, c'est la France entière.

## Installer

Le cluster n'a pas de contrôle d'admission : la signature du chart et des images se vérifie **avant** l'installation, avec **cosign ≥ 3** ([releases](https://github.com/sigstore/cosign/releases)) : celui des distributions (2.x) ne lit pas les signatures en bundle OCI que produit la CI.

```
ISSUER=https://token.actions.githubusercontent.com
CHART_ID='^https://github\.com/labatailledefrance/\.github/\.github/workflows/chart\.yml@.+$'
IMAGE_ID='^https://github\.com/labatailledefrance/\.github/\.github/workflows/image\.yml@.+$'
VERSION=0.3.0
SERVER=sha256:…      # digests publiés par la CI de chaque dépôt
CLIENT=sha256:…
DATACHAIN=sha256:…
ASSETS=sha256:…

cosign verify ghcr.io/labatailledefrance/charts/game:$VERSION --certificate-identity-regexp "$CHART_ID" --certificate-oidc-issuer "$ISSUER"
for i in beta1-server@$SERVER beta1-client@$CLIENT beta1-datachain@$DATACHAIN beta1-assets@$ASSETS; do
  cosign verify ghcr.io/labatailledefrance/$i --certificate-identity-regexp "$IMAGE_ID" --certificate-oidc-issuer "$ISSUER"
done

helm upgrade --install game oci://ghcr.io/labatailledefrance/charts/game --version $VERSION \
  -n labatailledefrance --create-namespace \
  --set server.image.digest=$SERVER --set client.image.digest=$CLIENT \
  --set datachain.image.digest=$DATACHAIN --set assets.image.digest=$ASSETS
```

Sur srv, `KUBECONFIG=/etc/rancher/k3s/k3s.yaml`. Une mise à jour remet le monde à zéro.

Chart et images sont publics sur ghcr.io : ni connexion ni secret de tirage.

### Première installation : copier les sources avant de télécharger

Les 669 Go de sources de P-26 sont déjà sur srv, et Poly Pizza refuse les IP de datacenter (les 8 modèles Quaternius se téléchargent depuis une machine personnelle). On crée donc les PVC sans lancer les Jobs, on les remplit, puis on lance les Jobs :

1. Même commande que ci-dessus, avec `--set stockage.noeud=srv --set datachain.suspendu=true --set assets.suspendu=true`. Avec `stockage.noeud`, local-path crée les PVC tout de suite, au lieu d'attendre le premier pod qui les monte.
2. Copier les fichiers dans les dossiers des PVC, puis les donner à l'utilisateur 65532 :

   ```
   pv() { kubectl get pv "$(kubectl -n labatailledefrance get pvc "$1" -o jsonpath='{.spec.volumeName}')" -o jsonpath='{.spec.hostPath.path}{.spec.local.path}'; }
   sudo cp -a /srv/zombie-p26/sources/. "$(pv sources)/"        # copie (669 Go) : P-26 reste intact
   sudo mkdir -p "$(pv assets)/sources"                          # depuis la machine personnelle : rsync de data/sources/assets/
   sudo chown -R 65532:65532 "$(pv sources)" "$(pv assets)"
   ```

3. Relancer la même commande sans les `suspendu` (`spec.suspend` se modifie sans recréer les Jobs). Chaque Job vérifie les fichiers présents (taille, empreintes) et ne télécharge que les autres.

Jeton Sketchfab (facultatif si les quatre modèles ont été copiés) : `kubectl -n labatailledefrance create secret generic sketchfab --from-literal=token=…`, puis `--set assets.sketchfabSecret=sketchfab`.

## Vérifier en local

```
helm lint --strict charts/game -f charts/game/ci/test-values.yaml
helm template game charts/game -f charts/game/ci/test-values.yaml | kubeconform -strict -ignore-missing-schemas
```

Contribution : [CONTRIBUTING.md](https://github.com/labatailledefrance/.github/blob/main/CONTRIBUTING.md). Licence : AGPL-3.0-or-later.
