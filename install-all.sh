#!/usr/bin/env bash
#
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#  SD-Forge Neo — Fresh Linux Full Installer
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#
#  One-liner:
#    curl -fsSL https://raw.githubusercontent.com/ArthureCodage/sd-forge-ollama-prompt/master/install-all.sh | bash
#
#  Or with custom options:
#    curl -fsSL ... | bash -s -- --model llama3.2-vision --dir ~/sd-forge
#
#  Does EVERYTHING on a fresh Linux box:
#    System deps → Ollama → SDFN → Extensions → Ready to create
#
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

set -euo pipefail

# ─── Defaults ─────────────────────────────────────────────────────────────────

INSTALL_DIR="${SDFORGE_DIR:-$HOME/sd-forge-neo}"
OLLAMA_MODEL="${OLLAMA_MODEL:-llama3.2-vision}"
SDFORGE_REPO="https://github.com/Haoming02/sd-webui-forge-classic.git"
SDFORGE_BRANCH="neo"
EXT_OLLAMA_PROMPT="https://github.com/ArthureCodage/sd-forge-ollama-prompt.git"
EXT_CIVITAI_HELPER="https://github.com/ArthureCodage/sd-forge-civitai-helper.git"
AUTO_YES=false

# ─── Colors ───────────────────────────────────────────────────────────────────

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

info()    { echo -e "${BLUE}[INFO]${NC} $*"; }
success() { echo -e "${GREEN}[✓]${NC} $*"; }
warn()    { echo -e "${YELLOW}[!]${NC} $*"; }
error()   { echo -e "${RED}[✗]${NC} $*"; }
header()  { echo -e "\n${BOLD}${CYAN}━━━ $* ━━━${NC}\n"; }
step()    { echo -e "\n${BOLD}▸ $*${NC}"; }

# ─── Parse args ───────────────────────────────────────────────────────────────

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --dir)       INSTALL_DIR="$2"; shift 2 ;;
            --model)     OLLAMA_MODEL="$2"; shift 2 ;;
            --yes|-y)    AUTO_YES=true; shift ;;
            --help|-h)
                echo "Usage: $0 [--dir PATH] [--model MODEL] [--yes]"
                exit 0
                ;;
            *) shift ;;
        esac
    done
}

# ─── Detect distro ────────────────────────────────────────────────────────────

detect_distro() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        echo "${ID,,}"
    elif check_command apt-get; then
        echo "debian"
    elif check_command dnf; then
        echo "fedora"
    elif check_command pacman; then
        echo "arch"
    else
        echo "unknown"
    fi
}

# ─── Helpers ──────────────────────────────────────────────────────────────────

check_command() {
    command -v "$1" &>/dev/null
}

confirm_or_skip() {
    if $AUTO_YES; then return 0; fi
    local prompt="${1:-Continuer ?} [O/n] "
    read -rp "$prompt" answer
    [[ "${answer,,}" != "n" ]]
}

# ─── 1. System Dependencies ──────────────────────────────────────────────────

install_system_deps() {
    header "1/6 — Dépendances système"

    local distro
    distro=$(detect_distro)
    info "Distribution détectée: ${distro}"

    local common_deps="git curl wget ca-certificates build-essential"

    # Detect Python major.minor for versioned packages
    local py_major_minor
    py_major_minor=$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')

    case "$distro" in
        ubuntu|debian|linuxmint|pop)
            sudo apt-get update -qq
            sudo apt-get install -y -qq \
                software-properties-common \
                ${common_deps} \
                python3 python3-venv python3-dev python3-pip \
                "python3-${py_major_minor}-venv" \
                "python3-distutils" \
                libgl1-mesa-glx libglib2.0-0 libsm6 libxext6 libxrender-dev \
                libglfw3 libglfw3-dev \
                ffmpeg \
                2>&1 | tail -5
            ;;
        fedora|rhel|centos)
            sudo dnf install -y -q \
                ${common_deps} \
                python3 python3-devel python3-virtualenv \
                mesa-libGL glib2 libSM libXext libXrender \
                glfw glfw-devel \
                ffmpeg \
                2>&1 | tail -5
            ;;
        arch|manjaro|endeavouros)
            sudo pacman -Syu --noconfirm --quiet \
                base-devel \
                ${common_deps} \
                python python-virtualenv \
                mesa glib2 libsm libxext libxrender \
                glfw-x11 \
                ffmpeg \
                2>&1 | tail -5
            ;;
        *)
            warn "Distribution non reconnue — skip des deps système"
            warn "Installez manuellement: git, python3, python3-venv, curl, mesa-libGL"
            ;;
    esac

    success "Dépendances système installées"
}

# ─── 2. Python Environment ────────────────────────────────────────────────────

setup_python() {
    header "2/6 — Environnement Python"

    local py_cmd="python3"

    # Check Python version
    local py_version
    py_version=$($py_cmd --version 2>&1 | awk '{print $2}')
    info "Python ${py_version} détecté"

    # Create install directory
    mkdir -p "$INSTALL_DIR"
    cd "$INSTALL_DIR"

    # Create venv
    if [[ -f "venv/bin/activate" ]] && [[ -f "venv/bin/pip" ]]; then
        info "Venv existant trouvé"
    else
        info "Création du venv..."

        # Remove broken venv if exists
        rm -rf venv

        # Try standard venv creation
        if $py_cmd -m venv venv 2>/dev/null; then
            success "Venv créé (standard)"
        else
            warn "ensurepip non disponible — fallback method..."
            $py_cmd -m venv --without-pip venv
            curl -fsSL https://bootstrap.pypa.io/get-pip.py | $py_cmd
            rm -f get-pip.py
            success "Venv créé (fallback get-pip)"
        fi
    fi

    source venv/bin/activate

    # Verify pip is available
    if ! check_command pip; then
        warn "pip manquant dans le venv — installation..."
        curl -fsSL https://bootstrap.pypa.io/get-pip.py | python3
        rm -f get-pip.py
    fi

    # Upgrade pip
    info "Mise à jour de pip..."
    pip install --upgrade pip wheel setuptools -q 2>&1 | tail -1
    success "pip à jour ($(pip --version | awk '{print $2}'))"
}

# ─── 3. Install Ollama ───────────────────────────────────────────────────────

install_ollama() {
    header "3/6 — Installation d'Ollama"

    if check_command ollama; then
        local ver
        ver=$(ollama --version 2>&1 | grep -oP 'version is \K[0-9.]+' || echo "unknown")
        success "Ollama déjà installé (v${ver})"
    else
        info "Installation d'Ollama..."
        curl -fsSL https://ollama.com/install.sh | sh

        if ! check_command ollama; then
            error "Échec installation Ollama"
            exit 1
        fi
        success "Ollama installé"
    fi

    # Start service
    step "Démarrage du service Ollama"
    if systemctl is-active --quiet ollama 2>/dev/null; then
        info "Service déjà actif"
    else
        sudo systemctl enable ollama 2>/dev/null || true
        sudo systemctl start ollama 2>/dev/null || true

        if ! systemctl is-active --quiet ollama 2>/dev/null; then
            nohup ollama serve > /tmp/ollama.log 2>&1 &
            sleep 5
        fi
    fi

    # Wait for ready
    local retries=0
    while ! curl -s http://localhost:11434/api/tags > /dev/null 2>&1; do
        sleep 2
        ((retries++))
        [[ $retries -gt 30 ]] && { error "Ollama ne répond pas"; exit 1; }
    done
    success "Ollama opérationnel (http://localhost:11434)"

    # Pull model
    step "Téléchargement du modèle: ${OLLAMA_MODEL}"

    if ollama list 2>/dev/null | grep -q "${OLLAMA_MODEL%%:*}"; then
        info "Modèle ${OLLAMA_MODEL} déjà présent"
    else
        info "Téléchargement en cours (peut prendre 5-15 min)..."
        ollama pull "$OLLAMA_MODEL"
        success "Modèle ${OLLAMA_MODEL} téléchargé"
    fi
}

# ─── 4. Install SDFN ─────────────────────────────────────────────────────────

install_sdfn() {
    header "4/6 — Installation de Stable Diffusion Forge Neo"

    cd "$INSTALL_DIR"

    # Clone or update
    if [[ -d ".git" ]]; then
        info "SDFN déjà cloné — mise à jour..."
        git fetch origin
        git checkout "$SDFORGE_BRANCH" 2>/dev/null || true
        git pull origin "$SDFORGE_BRANCH" 2>/dev/null || true
        success "SDFN à jour (branche: ${SDFORGE_BRANCH})"
    elif [[ -d "webui.py" ]] || [[ $(ls -A | wc -l) -gt 1 ]]; then
        warn "Dossier non vide trouné — backup et re-clone"
        local backup="${INSTALL_DIR}.backup.$(date +%s)"
        mkdir -p "$backup"
        cp -r "$INSTALL_DIR"/* "$backup/" 2>/dev/null || true
        rm -rf "${INSTALL_DIR:?}/"*
        clone_sdfn
    else
        clone_sdfn
    fi

    # Install PyTorch
    step "Installation de PyTorch (CUDA)"
    source venv/bin/activate

    if python3 -c "import torch; exit(0 if torch.cuda.is_available() else 1)" 2>/dev/null; then
        info "PyTorch avec CUDA déjà installé"
    else
        info "Installation de PyTorch + CUDA 12.1..."
        pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121 \
            --progress-bar on 2>&1 | tail -3
        success "PyTorch installé"
    fi

    # Install SDFN requirements
    step "Installation des dépendances SDFN (5-10 min)"
    if [[ -f "requirements_versions.txt" ]]; then
        pip install -r requirements_versions.txt --progress-bar on 2>&1 | tail -3
    fi
    if [[ -f "requirements.txt" ]]; then
        pip install -r requirements.txt --progress-bar on 2>&1 | tail -3
    fi

    success "SDFN prêt"
}

clone_sdfn() {
    info "Clonage de SDFN (branche: ${SDFORGE_BRANCH})..."
    git clone --branch "$SDFORGE_BRANCH" --depth 1 "$SDFORGE_REPO" "$INSTALL_DIR"
    success "SDFN cloné dans ${INSTALL_DIR}"
}

# ─── 5. Install Extensions ────────────────────────────────────────────────────

install_extensions() {
    header "5/6 — Installation des extensions"

    mkdir -p "${INSTALL_DIR}/extensions"

    # Ollama Prompt
    if [[ -d "${INSTALL_DIR}/extensions/sd-forge-ollama-prompt" ]]; then
        info "sd-forge-ollama-prompt: mise à jour..."
        cd "${INSTALL_DIR}/extensions/sd-forge-ollama-prompt" && git pull 2>/dev/null || true
    else
        info "sd-forge-ollama-prompt: installation..."
        git clone --depth 1 "$EXT_OLLAMA_PROMPT" "${INSTALL_DIR}/extensions/sd-forge-ollama-prompt"
    fi
    success "sd-forge-ollama-prompt OK"

    # CivitAI Helper
    if [[ -d "${INSTALL_DIR}/extensions/sd-forge-civitai-helper" ]]; then
        info "sd-forge-civitai-helper: mise à jour..."
        cd "${INSTALL_DIR}/extensions/sd-forge-civitai-helper" && git pull 2>/dev/null || true
    else
        info "sd-forge-civitai-helper: installation..."
        git clone --depth 1 "$EXT_CIVITAI_HELPER" "${INSTALL_DIR}/extensions/sd-forge-civitai-helper"
    fi
    success "sd-forge-civitai-helper OK"

    # Run extension install.py if present
    for ext in "${INSTALL_DIR}/extensions/"*/install.py; do
        if [[ -f "$ext" ]]; then
            info "Exécution de ${ext}..."
            python3 "$ext" 2>&1 | tail -3 || warn "install.py a échoué (non-critique)"
        fi
    done
}

# ─── 6. Create Launcher ───────────────────────────────────────────────────────

create_launcher() {
    header "6/6 — Création du lanceur"

    cat > "${INSTALL_DIR}/start.sh" << LAUNCHER
#!/usr/bin/env bash
# SD-Forge Neo — Quick Launcher
set -euo pipefail
cd "\$(dirname "\$0")"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Démarrage de SD-Forge Neo"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check/start Ollama
if ! curl -s http://localhost:11434/api/tags > /dev/null 2>&1; then
    echo "[*] Ollama non démarré..."
    if systemctl is-enabled ollama &>/dev/null; then
        sudo systemctl start ollama
    else
        nohup ollama serve > /tmp/ollama.log 2>&1 &
    fi
    sleep 5
fi

if curl -s http://localhost:11434/api/tags > /dev/null 2>&1; then
    echo "[✓] Ollama opérationnel"
else
    echo "[!] Ollama ne répond pas"
fi

# Activate venv and launch
source venv/bin/activate
echo "[*] Lancement de SDFN...\n"

python webui.py \\
    --api \\
    --listen \\
    --enable-insecure-extension-access \\
    "\$@"
LAUNCHER

    chmod +x "${INSTALL_DIR}/start.sh"

    # Bash alias suggestion
    local shell_rc="$HOME/.bashrc"
    [[ "$SHELL" == */zsh ]] && shell_rc="$HOME/.zshrc"

    if ! grep -q "alias sdfn=" "$shell_rc" 2>/dev/null; then
        echo "" >> "$shell_rc"
        echo "# SD-Forge Neo" >> "$shell_rc"
        echo "alias sdfn='cd ${INSTALL_DIR} && ./start.sh'" >> "$shell_rc"
        info "Alias ajouté: tapez 'sdfn' pour démarrer"
    fi

    success "Lanceur créé: ${INSTALL_DIR}/start.sh"
}

# ─── Summary ──────────────────────────────────────────────────────────────────

show_summary() {
    header "🎉 Installation terminée !"

    echo -e "  ${GREEN}${BOLD}Tout est prêt !${NC}\n"
    echo -e "  ${CYAN}📁 Emplacement:${NC}  ${INSTALL_DIR}"
    echo -e "  ${CYAN}🤖 Ollama:${NC}        http://localhost:11434 (modèle: ${OLLAMA_MODEL})"
    echo -e "  ${CYAN}🧩 Extensions:${NC}"
    echo -e "     • sd-forge-ollama-prompt  — Génération auto de prompts"
    echo -e "     • sd-forge-civitai-helper — Download/scan modèles CivitAI"
    echo ""
    echo -e "  ${BOLD}Pour démarrer:${NC}\n"
    echo -e "     ${YELLOW}cd ${INSTALL_DIR}${NC}"
    echo -e "     ${YELLOW}./start.sh${NC}"
    echo ""
    echo -e "  ${BOLD}Ou via alias (après un source ~/.bashrc):${NC}"
    echo -e "     ${YELLOW}sdfn${NC}"
    echo ""
    echo -e "  ${BOLD}Flags utiles:${NC}"
    echo -e "     ${YELLOW}./start.sh --xformers --autolaunch --theme dark${NC}"
    echo ""
    echo -e "  ${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "  ${GREEN}Bonne création ! 🎨${NC}\n"
}

# ─── Main ─────────────────────────────────────────────────────────────────────

main() {
    parse_args "$@"

    clear
    echo ""
    echo -e "  ${BOLD}${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "  ${BOLD}${CYAN}║                                                              ║${NC}"
    echo -e "  ${BOLD}${CYAN}║   SD-Forge Neo — Fresh Linux Installer                       ║${NC}"
    echo -e "  ${BOLD}${CYAN}║   ─────────────────────────────────                         ║${NC}"
    echo -e "  ${BOLD}${CYAN}║   Tout installe en une commande                             ║${NC}"
    echo -e "  ${BOLD}${CYAN}║   Ubuntu / Debian / Fedora / Arch                            ║${NC}"
    echo -e "  ${BOLD}${CYAN}║                                                              ║${NC}"
    echo -e "  ${BOLD}${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    info "Dossier: ${INSTALL_DIR}"
    info "Modèle:  ${OLLAMA_MODEL}"
    echo ""

    confirm_or_skip "Lancer l'installation ?" || exit 0

    install_system_deps
    setup_python
    install_ollama
    install_sdfn
    install_extensions
    create_launcher
    show_summary
}

main "$@"
