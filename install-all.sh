#!/usr/bin/env bash
#
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#  SD-Forge Neo — Full Installer for Linux
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#
#  Installs in one go:
#    1. Ollama (local LLM server)
#    2. Stable Diffusion Forge Neo (SDFN)
#    3. sd-forge-ollama-prompt (auto prompt generation via Ollama)
#    4. sd-forge-civitai-helper (CivitAI model downloader)
#
#  Usage:
#    chmod +x install-all.sh
#    ./install-all.sh
#
#  Or with custom install path:
#    SDFORGE_DIR=~/sd-forge ./install-all.sh
#
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

set -euo pipefail

# ─── Configuration ────────────────────────────────────────────────────────────

INSTALL_DIR="${SDFORGE_DIR:-$HOME/sd-forge-neo}"
SDFORGE_REPO="https://github.com/Haoming02/sd-webui-forge-classic.git"
SDFORGE_BRANCH="neo"
EXT_OLLAMA_PROMPT="https://github.com/ArthureCodage/sd-forge-ollama-prompt.git"
EXT_CIVITAI_HELPER="https://github.com/ArthureCodage/sd-forge-civitai-helper.git"

OLLAMA_MODEL="${OLLAMA_MODEL:-llama3.2}"
PYTHON_MIN_VERSION="3.10"

# ─── Colors & formatting ──────────────────────────────────────────────────────

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

info()    { echo -e "${BLUE}[INFO]${NC} $*"; }
success() { echo -e "${GREEN}[✓]${NC} $*"; }
warn()    { echo -e "${YELLOW}[!]${NC} $*"; }
error()   { echo -e "${RED}[✗]${NC} $*"; }
header()  { echo -e "\n${BOLD}${CYAN}━━━ $* ━━━${NC}\n"; }
step()    { echo -e "\n${BOLD}▸ $1${NC}"; }

# ─── Helpers ──────────────────────────────────────────────────────────────────

check_command() {
    command -v "$1" &>/dev/null
}

version_ge() {
    # Returns 0 if $1 >= $2
    printf '%s\n%s\n' "$2" "$1" | sort -V -C
}

confirm_or_default() {
    local prompt="$1"
    local default="$2"
    read -rp "$prompt [$default]: " answer
    echo "${answer:-$default}"
}

# ─── Pre-flight checks ────────────────────────────────────────────────────────

preflight() {
    header "Pré-installation — Vérification du système"

    local errors=0

    # Check OS
    if [[ "$(uname -s)" != "Linux" ]]; then
        error "Ce script est conçu pour Linux uniquement."
        error "For other OS, please install manually."
        ((errors++))
    else
        info "Système: $(uname -s) $(uname -r) ($(uname -m))"
    fi

    # Check Python
    if check_command python3; then
        PYTHON_VERSION=$(python3 --version 2>&1 | awk '{print $2}')
        if version_ge "$PYTHON_VERSION" "$PYTHON_MIN_VERSION"; then
            success "Python $PYTHON_VERSION détecté"
        else
            error "Python $PYTHON_VERSION trouvé. Minimum requis: $PYTHON_MIN_VERSION"
            ((errors++))
        fi
    else
        error "Python3 non trouvé. Installez Python $PYTHON_MIN_VERSION+ d'abord."
        ((errors++))
    fi

    # Check pip
    if check_command pip3 || python3 -m pip --version &>/dev/null; then
        success "pip disponible"
    else
        warn "pip non trouvé — sera installé avec le venv"
    fi

    # Check git
    if check_command git; then
        success "Git $(git --version | awk '{print $3}')"
    else
        error "Git non trouvé. Installez-le: sudo apt install git"
        ((errors++))
    fi

    # Check GPU (optional but recommended)
    if check_command nvidia-smi; then
        GPU_INFO=$(nvidia-smi --query-gpu=name,memory.total --format=csv,noheader 2>/dev/null | head -1)
        success "GPU NVIDIA détecté: $GPU_INFO"
    elif check_command rocminfo 2>/dev/null; then
        success "GPU AMD détecté (ROCm)"
    else
        warn "Aucun GPU détecté. SDFN fonctionnera en mode CPU (très lent)."
    fi

    # Check disk space (need at least 20GB free)
    AVAIL_GB=$(df -BG "$HOME" | awk 'NR==2 {print $4}' | tr -d 'G')
    if [[ "$AVAIL_GB" -ge 20 ]]; then
        success "Espace disque: ${AVAIL_GB}GB disponible"
    else
        warn "Espace disque faible: ${AVAIL_GB}GB (20GB+ recommandé)"
    fi

    # Check RAM
    TOTAL_RAM=$(free -g | awk '/^Mem:/{print $2}')
    if [[ "$TOTAL_RAM" -ge 8 ]]; then
        success "RAM: ${TOTAL_RAM}GB"
    else
        warn "RAM: ${TOTAL_RAM}GB (8GB+ recommandé pour SDFN)"
    fi

    if [[ $errors -gt 0 ]]; then
        echo ""
        error "$errors erreur(s) bloquante(s). Corrigez-les avant de continuer."
        exit 1
    fi

    echo ""
    success "Vérifications passées !"
}

# ─── Install Ollama ───────────────────────────────────────────────────────────

install_ollama() {
    header "1/4 — Installation d'Ollama"

    if check_command ollama; then
        OLLAMA_VERSION=$(ollama --version 2>&1 | awk '{print $3}' || echo "unknown")
        success "Ollama déjà installé (v${OLLAMA_VERSION})"
    else
        info "Installation d'Ollama via le script officiel..."
        curl -fsSL https://ollama.com/install.sh | sh

        if check_command ollama; then
            success "Ollama installé avec succès"
        else
            error "Échec de l'installation d'Ollama"
            exit 1
        fi
    fi

    # Start Ollama service
    step "Démarrage du service Ollama"

    if systemctl is-active --quiet ollama 2>/dev/null; then
        info "Service Ollama déjà actif"
    else
        info "Activation du service Ollama..."
        sudo systemctl enable ollama 2>/dev/null || true
        sudo systemctl start ollama 2>/dev/null || true

        # Fallback: start in background if systemd not available
        if ! systemctl is-active --quiet ollama 2>/dev/null; then
            info "Démarrage d'Ollama en arrière-plan..."
            nohup ollama serve > /tmp/ollama.log 2>&1 &
            sleep 3
        fi
    fi

    # Wait for Ollama to be ready
    info "Attente qu'Ollama soit prêt..."
    local retries=0
    while ! curl -s http://localhost:11434/api/tags > /dev/null 2>&1; do
        sleep 2
        ((retries++))
        if [[ $retries -gt 30 ]]; then
            error "Ollama ne répond pas après 60 secondes"
            error "Vérifiez les logs: journalctl -u ollama"
            exit 1
        fi
    done
    success "Ollama est opérationnel (http://localhost:11434)"

    # Pull model
    step "Téléchargement du modèle LLM: ${OLLAMA_MODEL}"

    if ollama list 2>/dev/null | grep -q "$OLLAMA_MODEL"; then
        info "Modèle ${OLLAMA_MODEL} déjà présent"
    else
        info "Téléchargement de ${OLLAMA_MODEL} (peut prendre plusieurs minutes)..."
        ollama pull "$OLLAMA_MODEL"
        success "Modèle ${OLLAMA_MODEL} téléchargé"
    fi
}

# ─── Install SDFN ─────────────────────────────────────────────────────────────

install_sdfn() {
    header "2/4 — Installation de Stable Diffusion Forge Neo"

    if [[ -d "$INSTALL_DIR" ]]; then
        info "Dossier ${INSTALL_DIR} existant"

        if [[ -d "$INSTALL_DIR/.git" ]]; then
            info "Mise à jour du repo SDFN..."
            cd "$INSTALL_DIR"
            git fetch origin
            git checkout "$SDFORGE_BRANCH" 2>/dev/null || true
            git pull origin "$SDFORGE_BRANCH" 2>/dev/null || true
            success "SDFN mis à jour (branche: ${SDFORGE_BRANCH})"
        else
            warn "Dossier non-git trouvé. Sauvegarde et re-clone..."
            mv "$INSTALL_DIR" "${INSTALL_DIR}.backup.$(date +%s)"
            clone_sdfn
        fi
    else
        clone_sdfn
    fi

    # Create virtual environment
    step "Environnement Python"

    if [[ -f "$INSTALL_DIR/venv/bin/activate" ]]; then
        info "Venv existant trouvé"
    else
        info "Création de l'environnement virtuel..."
        python3 -m venv "$INSTALL_DIR/venv"
        success "Venv créé"
    fi

    source "$INSTALL_DIR/venv/bin/activate"

    # Upgrade pip
    info "Mise à jour de pip..."
    pip install --upgrade pip wheel setuptools -q
    success "pip à jour"

    # Install torch with GPU support
    step "Installation de PyTorch"

    if python3 -c "import torch; assert torch.cuda.is_available()" 2>/dev/null; then
        info "PyTorch avec CUDA déjà installé"
    elif python3 -c "import torch" 2>/dev/null; then
        warn "PyTorch installé sans CUDA — réinstallation..."
        pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121
    else
        info "Installation de PyTorch (CUDA 12.1)..."
        pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121
    fi

    # Install SDFN requirements
    step "Installation des dépendances SDFN"
    cd "$INSTALL_DIR"

    if [[ -f "requirements_versions.txt" ]]; then
        pip install -r requirements_versions.txt --progress-bar on
    elif [[ -f "requirements.txt" ]]; then
        pip install -r requirements.txt --progress-bar on
    fi

    success "Dépendances SDFN installées"
}

clone_sdfn() {
    info "Clonage de SDFN (branche: ${SDFORGE_BRANCH})..."
    git clone --branch "$SDFORGE_BRANCH" --depth 1 "$SDFORGE_REPO" "$INSTALL_DIR"
    success "SDFN cloné dans ${INSTALL_DIR}"
}

# ─── Install Extensions ───────────────────────────────────────────────────────

install_extensions() {
    header "3/4 — Installation des extensions"

    local ext_dir="${INSTALL_DIR}/extensions"
    mkdir -p "$ext_dir"

    # Extension 1: Ollama Prompt
    step "sd-forge-ollama-prompt"
    install_single_extension \
        "$EXT_OLLAMA_PROMPT" \
        "sd-forge-ollama-prompt" \
        "$ext_dir"

    # Extension 2: CivitAI Helper
    step "sd-forge-civitai-helper"
    install_single_extension \
        "$EXT_CIVITAI_HELPER" \
        "sd-forge-civitai-helper" \
        "$ext_dir"
}

install_single_extension() {
    local repo_url="$1"
    local folder_name="$2"
    local parent_dir="$3"
    local target="${parent_dir}/${folder_name}"

    if [[ -d "$target" ]]; then
        info "${folder_name} déjà présent — mise à jour..."
        cd "$target"
        git pull 2>/dev/null || warn "Mise à jour impossible (repo local modifié?)"
        success "${folder_name} à jour"
    else
        info "Clonage de ${folder_name}..."
        git clone --depth 1 "$repo_url" "$target"
        success "${folder_name} installé"
    fi
}

# ─── Create launcher script ───────────────────────────────────────────────────

create_launcher() {
    header "4/4 — Création du lanceur"

    local launcher="${INSTALL_DIR}/start.sh"

    cat > "$launcher" << 'LAUNCHER_EOF'
#!/usr/bin/env bash
#
#  SD-Forge Neo — Quick Launcher
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Démarrage de SD-Forge Neo"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check Ollama
if ! curl -s http://localhost:11434/api/tags > /dev/null 2>&1; then
    echo "[INFO] Ollama non démarré — tentative de démarrage..."
    if systemctl is-enabled ollama &>/dev/null; then
        sudo systemctl start ollama
    else
        nohup ollama serve > /tmp/ollama.log 2>&1 &
    fi
    sleep 3
fi

if curl -s http://localhost:11434/api/tags > /dev/null 2>&1; then
    echo "[✓] Ollama opérationnel"
else
    echo "[!] Ollama ne répond pas — l'extension Ollama Prompt ne fonctionnera pas"
fi

# Activate venv and launch
source venv/bin/activate

echo "[*] Lancement de SDFN..."
echo ""

# Launch with recommended flags
python webui.py \
    --api \
    --listen \
    --enable-insecure-extension-access \
    "$@"
LAUNCHER_EOF

    chmod +x "$launcher"

    # Create Ollama-only launcher
    local ollama_launcher="${INSTALL_DIR}/start-ollama.sh"
    cat > "$ollama_launcher" << 'OLLAMA_EOF'
#!/usr/bin/env bash
# Quick start Ollama only
echo "Démarrage d'Ollama..."
ollama serve
OLLAMA_EOF
    chmod +x "$ollama_launcher"

    success "Lanceurs créés:"
    info "  ${INSTALL_DIR}/start.sh          — Lancer SDFN"
    info "  ${INSTALL_DIR}/start-ollama.sh   — Lancer Ollama seul"
}

# ─── Final summary ────────────────────────────────────────────────────────────

show_summary() {
    header "Installation terminée !"

    echo -e "  ${GREEN}${BOLD}Tout est prêt !${NC}\n"
    echo -e "  ${CYAN}📥 Installer one-liner:${NC}"
    echo -e "     ${YELLOW}curl -fsSL https://raw.githubusercontent.com/ArthureCodage/sd-forge-ollama-prompt/master/install-all.sh | bash${NC}\n"

    echo -e "  ${CYAN}📁 Emplacement:${NC}  ${INSTALL_DIR}"
    echo -e "  ${CYAN}🐍 Python:${NC}        ${PYTHON_VERSION} (venv: ${INSTALL_DIR}/venv)"
    echo -e "  ${CYAN}🤖 Ollama:${NC}        http://localhost:11434 (modèle: ${OLLAMA_MODEL})"
    echo -e "  ${CYAN}🧩 Extensions:${NC}"
    echo -e "     • sd-forge-ollama-prompt  (génération de prompts)"
    echo -e "     • sd-forge-civitai-helper (download CivitAI)"
    echo ""

    echo -e "  ${BOLD}Pour démarrer:${NC}\n"
    echo -e "     ${YELLOW}cd ${INSTALL_DIR}${NC}"
    echo -e "     ${YELLOW}./start.sh${NC}"
    echo ""

    echo -e "  ${BOLD}Ou avec des flags personnalisés:${NC}\n"
    echo -e "     ${YELLOW}./start.sh --xformers --autolaunch --theme dark${NC}"
    echo ""

    echo -e "  ${BOLD}Accès interface:${NC}"
    echo -e "     🌐 Local:    ${CYAN}http://localhost:7860${NC}"
    echo -e "     🌐 Réseau:   ${CYAN}http://$(hostname -I 2>/dev/null | awk '{print $1}' || echo '0.0.0.0'):7860${NC}"
    echo ""

    echo -e "  ${BOLD}Utilisation de l'extension Ollama Prompt:${NC}"
    echo -e "     1. Ouvrez l'onglet '${CYAN}Ollama Prompt${NC}' dans SDFN"
    echo -e "     2. Cliquez '${CYAN}Tester${NC}' pour vérifier la connexion"
    echo -e "     3. Entrez un thème et générez votre prompt !"
    echo ""

    echo -e "  ${BOLD}Raccourci bash (optionnel):${NC}\n"
    echo -e "     echo 'alias sdfn=\"cd ${INSTALL_DIR} && ./start.sh\"' >> ~/.bashrc"
    echo -e "     ${YELLOW}source ~/.bashrc${NC}"
    echo -e "     ${YELLOW}sdfn${NC}  # lance tout !"
    echo ""

    echo -e "  ${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "  ${GREEN}Bonne création ! 🎨${NC}\n"
}

# ─── Main ─────────────────────────────────────────────────────────────────────

main() {
    clear

    echo ""
    echo -e "  ${BOLD}${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "  ${BOLD}${CYAN}║                                                              ║${NC}"
    echo -e "  ${BOLD}${CYAN}║   SD-Forge Neo — Installateur Complet                        ║${NC}"
    echo -e "  ${BOLD}${CYAN}║   ─────────────────────────────────                         ║${NC}"
    echo -e "  ${BOLD}${CYAN}║   Ollama + SDFN + Extensions                                 ║${NC}"
    echo -e "  ${BOLD}${CYAN}║                                                              ║${NC}"
    echo -e "  ${BOLD}${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    # Prompt for install directory
    INSTALL_DIR=$(confirm_or_default "Dossier d'installation" "$INSTALL_DIR")
    INSTALL_DIR="${INSTALL_DIR/#\~/$HOME}"  # Expand ~

    # Prompt for Ollama model
    OLLAMA_MODEL=$(confirm_or_default "Modèle Ollama à télécharger" "$OLLAMA_MODEL")

    echo ""
    info "Résumé:"
    info "  Installation: ${INSTALL_DIR}"
    info "  Modèle LLM:   ${OLLAMA_MODEL}"
    echo ""

    read -rp "Continuer ? [O/n] " confirm
    if [[ "${confirm,,}" == "n" ]]; then
        echo "Annulé."
        exit 0
    fi

    # Run installation steps
    preflight
    install_ollama
    install_sdfn
    install_extensions
    create_launcher
    show_summary
}

# Run
main "$@"
