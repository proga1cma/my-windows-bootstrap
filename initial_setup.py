# initial_setup_zip_download.py
import argparse
import os
import sys
import shutil
import platform
import zipfile
import requests # Эту зависимость нужно будет как-то решить

# --- Конфигурация ---
DEFAULT_MAIN_REPO_OWNER = "proga1cma"
DEFAULT_MAIN_REPO_NAME = "YOUR_MAIN_PRIVATE_AUTOMATION_REPO" # !!! ЗАМЕНИ !!!
DEFAULT_MAIN_REPO_BRANCH = "main"
DEFAULT_MAIN_REPO_LOCAL_DIR = "C:\\WindowsAutomationSetup"

def download_repo_zip(owner, repo_name, branch, target_zip_path, pat=None):
    """Скачивает ZIP-архив репозитория через GitHub API."""
    api_url = f"https://api.github.com/repos/{owner}/{repo_name}/zipball/{branch}"
    headers = {}
    if pat:
        headers["Authorization"] = f"token {pat}"
    
    print(f"[ИНФО] Скачивание ZIP-архива репозитория: {owner}/{repo_name} (ветка: {branch})")
    try:
        response = requests.get(api_url, headers=headers, stream=True, timeout=60)
        response.raise_for_status() # Проверка на HTTP ошибки
        with open(target_zip_path, 'wb') as f:
            for chunk in response.iter_content(chunk_size=8192):
                f.write(chunk)
        print(f"[УСПЕХ] ZIP-архив успешно скачан: {target_zip_path}")
        return True
    except requests.exceptions.RequestException as e:
        print(f"[ОШИБКА] Ошибка при скачивании ZIP-архива: {e}")
        if hasattr(e, 'response') and e.response is not None:
            print(f"Ответ сервера: {e.response.status_code} - {e.response.text[:200]}")
        return False

def extract_zip(zip_path, destination_path):
    """Распаковывает ZIP-архив."""
    print(f"[ИНФО] Распаковка архива {zip_path} в {destination_path}...")
    try:
        # Очищаем целевую директорию, если она существует
        if os.path.exists(destination_path):
            print(f"[ИНФО] Очистка существующей директории: {destination_path}")
            shutil.rmtree(destination_path)
        os.makedirs(destination_path, exist_ok=True)

        with zipfile.ZipFile(zip_path, 'r') as zip_ref:
            # GitHub ZIP-архивы обычно содержат одну папку верхнего уровня типа user-repo-commitsha
            # Нам нужно извлечь содержимое этой папки в destination_path
            top_level_dirs = list(set(item.split('/')[0] for item in zip_ref.namelist()))
            if len(top_level_dirs) == 1 and '/' in zip_ref.namelist()[0]: # Проверяем, что есть одна папка верхнего уровня
                prefix = top_level_dirs[0] + '/'
                for member in zip_ref.namelist():
                    if member.startswith(prefix):
                        target_path = os.path.join(destination_path, member[len(prefix):])
                        if member.endswith('/'): # это директория
                            os.makedirs(target_path, exist_ok=True)
                        else: # это файл
                            os.makedirs(os.path.dirname(target_path), exist_ok=True)
                            with open(target_path, 'wb') as outfile:
                                outfile.write(zip_ref.read(member))
            else: # Если структура не такая, извлекаем все как есть (может создать лишнюю папку)
                zip_ref.extractall(destination_path)
        print("[УСПЕХ] Архив успешно распакован.")
        return True
    except Exception as e:
        print(f"[ОШИБКА] Ошибка при распаковке архива: {e}")
        return False

def install_dependencies(project_dir, requirements_file="requirements.txt"):
    """Устанавливает зависимости из requirements.txt."""
    # Эта функция остается такой же, как в предыдущей версии initial_setup.py
    # ... (код функции install_dependencies) ...
    requirements_path = os.path.join(project_dir, requirements_file)
    if not os.path.exists(requirements_path):
        print(f"[ИНФО] Файл зависимостей '{requirements_file}' не найден в '{project_dir}'. Пропуск.")
        return True
    print(f"[ИНФО] Установка зависимостей из {requirements_path}...")
    try:
        subprocess.run([sys.executable, "-m", "pip", "install", "-r", requirements_path], check=True, cwd=project_dir)
        print("[УСПЕХ] Зависимости успешно установлены.")
        return True
    except subprocess.CalledProcessError as e:
        print(f"[ОШИБКА] Ошибка при установке зависимостей: {e}")
        return False

def main():
    parser = argparse.ArgumentParser(description="Загрузчик основного проекта автоматизации (скачивание ZIP).")
    parser.add_argument(
        "--pat",
        help="GitHub Personal Access Token для доступа к приватному репозиторию."
    )
    parser.add_argument(
        "--owner", default=DEFAULT_MAIN_REPO_OWNER,
        help=f"Владелец основного приватного репозитория. По умолчанию: {DEFAULT_MAIN_REPO_OWNER}"
    )
    parser.add_argument(
        "--repo", default=DEFAULT_MAIN_REPO_NAME,
        help=f"Имя основного приватного репозитория. По умолчанию: {DEFAULT_MAIN_REPO_NAME}"
    )
    parser.add_argument(
        "--branch", default=DEFAULT_MAIN_REPO_BRANCH,
        help=f"Ветка основного приватного репозитория. По умолчанию: {DEFAULT_MAIN_REPO_BRANCH}"
    )
    parser.add_argument(
        "--target-dir", default=DEFAULT_MAIN_REPO_LOCAL_DIR,
        help=f"Локальная директория для распаковки. По умолчанию: {DEFAULT_MAIN_REPO_LOCAL_DIR}"
    )
    parser.add_argument(
        "--skip-main-runner", action="store_true",
        help="Пропустить автоматический запуск main_runner.py."
    )
    args = parser.parse_args()

    print("--- Запуск начальной настройки (скачивание ZIP) ---")

    github_pat = args.pat
    if not github_pat:
        print("[ПРЕДУПРЕЖДЕНИЕ] GitHub Personal Access Token (PAT) не предоставлен через аргумент --pat.")
        if 'GITHUB_PAT' in os.environ:
            github_pat = os.environ['GITHUB_PAT']
            print("[ИНФО] Используется PAT из переменной окружения GITHUB_PAT.")
        else:
            try:
                github_pat = input("Введите ваш GitHub Personal Access Token (или нажмите Enter для анонимного доступа, если репозиторий публичный): ").strip()
                if not github_pat:
                    print("[ИНФО] PAT не введен, попытка анонимного доступа (для публичных репозиториев).")
            except EOFError: # Если скрипт запускается неинтерактивно
                print("[ОШИБКА] Не удалось запросить PAT в неинтерактивном режиме. Используйте --pat или переменную окружения GITHUB_PAT.")
                sys.exit(1)


    temp_zip_file = os.path.join(os.getenv('TEMP', '.'), f"{args.repo}__{args.branch}.zip")

    # 1. Скачать ZIP приватного репозитория
    if not download_repo_zip(args.owner, args.repo, args.branch, temp_zip_file, github_pat):
        sys.exit(1)

    # 2. Распаковать архив
    if not extract_zip(temp_zip_file, args.target_dir):
        if os.path.exists(temp_zip_file): os.remove(temp_zip_file)
        sys.exit(1)
    
    if os.path.exists(temp_zip_file):
        os.remove(temp_zip_file) # Удаляем временный zip

    # 3. Установить зависимости (если есть requirements.txt)
    if not install_dependencies(args.target_dir):
        print("[ПРЕДУПРЕЖДЕНИЕ] Установка зависимостей не удалась.")

    print("\n--- Начальная настройка (скачивание ZIP) завершена! ---")
    print(f"Основной проект автоматизации распакован в: {args.target_dir}")

    # 4. (Опционально) Запустить main_runner.py
    if not args.skip_main_runner:
        # ... (логика запуска main_runner.py, как в предыдущем initial_setup.py) ...
        main_runner_path = os.path.join(args.target_dir, "main_runner.py")
        if os.path.exists(main_runner_path):
            print(f"\n[ИНФО] Попытка запуска основного скрипта: {main_runner_path}")
            print("---------------------------------------------------------------")
            try:
                subprocess.run([sys.executable, main_runner_path], check=True, cwd=args.target_dir, shell=(platform.system() == "Windows"))
            except Exception as e:
                print(f"[ОШИБКА] Ошибка при запуске main_runner.py: {e}")
        else:
            print(f"[ПРЕДУПРЕЖДЕНИЕ] Файл main_runner.py не найден в '{args.target_dir}'.")
    else:
        print(f"\n[ИНФО] Пропуск запуска main_runner.py. Для запуска: cd {args.target_dir} && python main_runner.py")


if __name__ == "__main__":
    # Проверка на Python
    if not (sys.version_info.major == 3 and sys.version_info.minor >= 6):
        print("[ОШИБКА] Требуется Python 3.6 или выше.")
        sys.exit(1)
    # Проверка на requests (нужно будет решить, как его доставить)
    try:
        import requests
    except ImportError:
        print("[ОШИБКА] Модуль 'requests' не найден. Пожалуйста, установите его: pip install requests")
        print("Или убедитесь, что он доступен для этого скрипта.")
        sys.exit(1)
    main()
