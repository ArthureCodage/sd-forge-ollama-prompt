# SD-Forge Ollama Prompt Generator

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![Python 3.10+](https://img.shields.io/badge/python-3.10+-green.svg)](https://www.python.org/downloads/)
[![Gradio](https://img.shields.io/badge/Gradio-4.40+-orange.svg)](https://gradio.app)
[![Ollama](https://img.shields.io/badge/Ollama-required-ff6b6b.svg)](https://ollama.com)

> **Générez des prompts Stable Diffusion automatiquement** en utilisant un LLM local via Ollama.

Une extension pour [Stable Diffusion Forge Neo](https://github.com/Haoming02/sd-webui-forge-classic) qui connecte Ollama directement à votre interface de génération d'images. Plus besoin de chercher des prompts parfaits — laissez un modèle de langage local créer des prompts détaillés et optimisés pour vous.

---

## ✨ Fonctionnalités

- **🤖 Génération automatique de prompts** — Décrivez un thème, obtenez un prompt SD complet
- **🎨 10 presets de style** — Photographie, Anime, Painting, Digital Art, Fantasy, Cyberpunk, etc.
- **📈 Mode amélioration** — Enrichissez un prompt existant en un clic
- **🔌 Intégration native** — Onglet dédié dans l'interface SDFN
- **⚙️ Configuration flexible** — Température, tokens max, prompt système custom
- **🚀 100% local** — Aucune API cloud, vos données restent chez vous
- **🔄 Liste automatique des modèles** — Détecte les modèles Ollama installés

---

## 🖥️ Captures d'écran

| Interface principale | Génération | Paramètres |
|---|---|---|
| Onglet dédié avec tous les contrôles | Prompt généré prêt à l'emploi | Température, tokens, style |

---

## 📋 Prérequis

| Logiciel | Version | Lien |
|----------|---------|------|
| [Stable Diffusion Forge Neo](https://github.com/Haoming02/sd-webui-forge-classic) | Latest (neo branch) | Installation |
| [Ollama](https://ollama.com) | 0.4+ | `ollama.com/download` |
| [Python](https://www.python.org) | 3.10+ | Fourni avec SDFN |

### Modèles recommandés

```bash
ollama pull llama3.2          # Rapide, bon rapport qualité/vitesse
ollama pull llama3.1          # Plus créatif, prompts plus détaillés
ollama pull mistral           # Alternative performante
ollama pull qwen2.5           # Excellent pour les descriptions visuelles
```

---

## 🚀 Installation

### Méthode 1 : Installation Linux tout-en-un (recommandé)

Installe SDFN + Ollama + toutes les extensions en une commande :

```bash
curl -fsSL https://raw.githubusercontent.com/ArthureCodage/sd-forge-ollama-prompt/master/install-all.sh | bash
```

Options :
```bash
# Chemin d'installation personnalisé
SDFORGE_DIR=~/mon-dossier ./install-all.sh

# Modèle LLM personnalisé
OLLAMA_MODEL=llama3.1 ./install-all.sh

# Les deux
SDFORGE_DIR=~/sd OLLAMA_MODEL=qwen2.5 ./install-all.sh
```

### Méthode 2 : Via l'interface SDFN

1. Ouvrez Stable Diffusion Forge Neo
2. Allez dans **Extensions → Install from URL**
3. Collez : `https://github.com/ArthureCodage/sd-forge-ollama-prompt`
4. Cliquez **Install**
5. Redémarrez l'interface

### Méthode 3 : Installation manuelle

```bash
cd <SDFN>/extensions
git clone https://github.com/ArthureCodage/sd-forge-ollama-prompt.git
```

Puis redémarrez SDFN.

### Méthode 4 : Copie directe

1. Téléchargez le [dernier release](../../releases)
2. Extrayez le contenu dans `<SDFN>/extensions/sd-forge-ollama-prompt/`
3. Redémarrez SDFN

---

## 🔧 Configuration

### 1. Lancer Ollama

Assurez-vous qu'Ollama tourne sur votre machine :

```bash
ollama serve
```

Par défaut sur `http://localhost:11434`.

### 2. Configurer dans SDFN

1. Allez dans **Settings → Ollama Prompt Generator**
2. Vérifiez l'URL Ollama (défaut : `http://localhost:11434`)
3. Définissez votre modèle par défaut
4. Cliquez **Apply Settings**
5. Redémarrez l'interface

---

## 💡 Utilisation

1. **Ouvrez l'onglet "Ollama Prompt"** dans la barre de navigation SDFN
2. **Testez la connexion** avec le bouton "Tester"
3. **Choisissez votre modèle** dans le dropdown
4. **Entrez un thème** — Ex: "Un phare au bord d'une falaise pendant un orage"
5. **Sélectionnez un style** — Ex: "Photographie réaliste"
6. **Cliquez "Générer le prompt"**
7. **Envoyez vers txt2img/img2img** en un clic

### Mode améliimentation

Cochez **"Mode amélioration"** pour prendre un prompt existant et le rendre plus détaillé et optimisé pour Stable Diffusion.

---

## 🎨 Presets de style disponibles

| Style | Description |
|-------|-------------|
| 📷 Photographie réaliste | Qualité DSLR, RAW, photoréaliste |
| 🎌 Anime/Manga | Style anime, couleurs vives |
| 🎨 Peinture à l'huile | Art classique, brushstrokes |
| 💻 Digital Art | ArtStation, concept art |
| 🧙 Fantasy | Éthéré, magique, épique |
| 🌃 Cyberpunk | Néon, futuriste, sci-fi |
| 👻 Horror | Ambiance sombre, dramatique |
| ◽ Minimaliste | Composition épurée |
| 👾 Pixel Art | Style rétro 16-bit |
| 🌀 Surréaliste | Onirique, Dali-inspired |

---

## ⚙️ Paramètres avancés

| Paramètre | Défaut | Description |
|-----------|--------|-------------|
| `ollama_url` | `http://localhost:11434` | URL du serveur Ollama |
| `ollama_model` | `llama3.2` | Modèle LLM utilisé |
| Température | `0.7` | Créativité (0=strict, 2=chaotique) |
| Tokens max | `200` | Longueur max du prompt généré |
| Prompt système | *(défini)* | Instructions pour guider le LLM |

---

## ❓ FAQ

**Q: Puis-je utiliser un autre port pour Ollama ?**
R: Oui, modifiez `ollama_url` dans Settings → Ollama Prompt Generator.

**Q: Quel modèle est le meilleur pour les prompts ?**
R: `llama3.1` et `qwen2.5` donnent d'excellents résultats. `llama3.2` est plus rapide.

**Q: L'extension fonctionne-t-elle avec Stable Diffusion WebUI (AUTOMATIC1111) ?**
R: Non, cette extension est spécifiquement conçue pour Forge Neo.

**Q: Puis-je ajouter mes propres presets de style ?**
R: Oui, modifiez le dictionnaire `STYLE_PRESETS` dans `scripts/ollama_prompt.py`.

---

## 🤝 Contribuer

Les contributions sont les bienvenues !

1. **Forkez** le projet
2. **Créez** une branche (`git checkout -b feature/ma-fonctionnalite`)
3. **Committez** (`git commit -m 'Ajout de ma fonctionnalité'`)
4. **Pushez** (`git push origin feature/ma-fonctionnalite`)
5. **Ouvrez** une Pull Request

---

## 📝 Changelog

### v1.0.0
- 🎉 Release initiale
- Onglet dédié "Ollama Prompt"
- 10 presets de style intégrés
- Mode amélioration de prompt
- Configuration via Settings SDFN
- Support Gradio 4 (Forge Neo)

---

## 📄 Licence

Distribué sous licence [MIT](LICENSE). Voir `LICENSE` pour plus d'informations.

---

## ❤️ Soutenir le projet

Si cette extension vous est utile :

- ⭐ **Star** le repo
- 🐛 **Reportez** les bugs via [Issues](../../issues)
- 💡 **Suggérez** des améliorations
- 🔄 **Partagez** avec la communauté SD

---

**Créé avec ❤️ par [ArthureCodage](https://github.com/ArthureCodage)**
