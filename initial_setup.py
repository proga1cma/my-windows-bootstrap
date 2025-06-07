# initial_setup.py
import argparse
import os
import subprocess
import sys
import shutil
import platform

# --- Конфигурация ---
# URL твоего основного ПРИВАТНОГО репозитория автоматизации
DEFAULT_MAIN_REPO_URL = "git@github.com:proga1cma/YOUR_MAIN_PRIVATE_AUTOMATION_REPO.git" # !!! ЗАМЕНИ !!!
DEFAULT_MAIN_REPO_LOCAL_DIR = "C:\\WindowsAutomationSetup" # Куда будет склонирован основной репозиторий
DEFAULT_REQUIREMENTS_FILE = "requirements.txt"

def get_default_ssh_key_path():
    """Возвращает стандартный путь к SSH ключу в зависимости от ОС."""
    home_dir = os.path.expanduser("~")
    return os.path.join(home_dir, ".ssh", "id_rsa")

def check_command_exists(command):
    """Проверяет, доступна ли команда в системе."""
    try:
        subprocess.run([command, "--version"], check=True, capture_output=True, text=True, shell=(platform.system() == "Windows"))
        print(f"[ИНФО] Команда '{command}' найдена.")
        return True
    except (subprocess.CalledProcessError, FileNotFoundError):
        print(f"[ОШИБКА] Команда '{command}' не найдена. Пожалуйста, убедитесь, что она установлена и добавлена в PATH.")
        return False

def configure_git_ssh(ssh_key_path):
    """Настраивает GIT_SSH_COMMAND для использования указанного SSH-ключа."""
    if not os.path.exists(ssh_key_path):
        print(f"[ОШИБКА] SSH-ключ не найден по пути: {ssh_key_path}")
        return False

    ssh_executable = "ssh.exe" if platform.system() == "Windows" else "ssh"
    # Для Windows используем 'nul', для Linux/macOS '/dev/null'
    null_device = "nul" if platform.system() == "Windows" else "/dev/null"
    
    # Нормализуем путь для использования в команде
    normalized_key_path = os.path.normpath(ssh_key_path)

    git_ssh_command = f'"{ssh_executable}" -i "{normalized_key_path}" -o StrictHostKeyChecking=no -o UserKnownHostsFile={null_device}'
    os.environ['GIT_SSH_COMMAND'] = git_ssh_command
    print(f"[ИНФО] GIT_SSH_COMMAND установлен: {git_ssh_command}")
    return True

def clone_repository(repo_url, target_dir):
    """Клонирует репозиторий в указанную директорию."""
    if os.path.exists(target_dir):
        print(f"[ПРЕДУПРЕЖДЕНИЕ] Директория '{target_dir}' уже существует.")
        overwrite = input(f"Удалить существующую директорию и клонировать заново? (y/n): ").strip().lower()
        if overwrite == 'y':
            print(f"[ИНФО] Удаление директории: {target_dir}")
            try:
                shutil.rmtree(target_dir)
            except Exception as e:
                print(f"[ОШИБКА] Ошибка при удалении директории {target_dir}: {e}")
                return False
        else:
            print("[ИНФО] Клонирование отменено. Используйте существующую директорию или выберите другую.")
            return True # Предположим, что пользователь хочет работать с существующей

    print(f"[ИНФО] Клонирование репозитория {repo_url} в {target_dir}...")
    try:
        # Убедимся, что родительская директория существует, если target_dir имеет несколько уровней
        # os.makedirs(os.path.dirname(target_dir), exist_ok=True) # shutil.rmtree уже удалил
        subprocess.run(["git", "clone", repo_url, target_dir], check=True, shell=(platform.system() == "Windows"))
        print("[УСПЕХ] Репозиторий успешно склонирован.")
        return True
    except subprocess.CalledProcessError as e:
        print(f"[ОШИБКА] Ошибка при клонировании репозитория: {e}")
        if hasattr(e, 'stderr') and e.stderr:
            print(f"Git stderr: {e.stderr.decode(errors='ignore') if isinstance(e.stderr, bytes) else e.stderr}")
        return False
    except FileNotFoundError:
        print("[ОШИБКА] Команда 'git' не найдена. Убедитесь, что Git установлен и в PATH.")
        return False

def install_dependencies(project_dir, requirements_file=DEFAULT_REQUIREMENTS_FILE):
    """Устанавливает зависимости из requirements.txt."""
    requirements_path = os.path.join(project_dir, requirements_file)
    if not os.path.exists(requirements_path):
        print(f"[ИНФО] Файл зависимостей '{requirements_file}' не найден в '{project_dir}'. Пропуск установки зависимостей.")
        return True

    print(f"[ИНФО] Установка зависимостей из {requirements_path}...")
    try:
        # Используем sys.executable для вызова pip из того же окружения Python
        subprocess.run([sys.executable, "-m", "pip", "install", "-r", requirements_path], check=True, cwd=project_dir)
        print("[УСПЕХ] Зависимости успешно установлены.")
        return True
    except subprocess.CalledProcessError as e:
        print(f"[ОШИБКА] Ошибка при установке зависимостей: {e}")
        return False

def main():
    parser = argparse.ArgumentParser(description="Загрузчик и настройщик основного проекта автоматизации Windows.")
    parser.add_argument(
        "--ssh-key-path",
        default=get_default_ssh_key_path(),
        help=f"Полный путь к вашему приватному SSH-ключу. По умолчанию: {get_default_ssh_key_path()}"
    )
    parser.add_argument(
        "--main-repo-url",
        default=DEFAULT_MAIN_REPO_URL,
        help=f"URL основного приватного Git-репозитория (SSH). По умолчанию: {DEFAULT_MAIN_REPO_URL}"
    )
    parser.add_argument(
        "--main-repo-dir",
        default=DEFAULT_MAIN_REPO_LOCAL_DIR,
        help=f"Локальная директория для клонирования основного репозитория. По умолчанию: {DEFAULT_MAIN_REPO_LOCAL_DIR}"
    )
    parser.add_argument(
        "--skip-main-runner",
        action="store_true",
        help="Пропустить автоматический запуск main_runner.py после установки."
    )

    args = parser.parse_args()

    print("--- Запуск начальной настройки (initial_setup.py) ---")

    # 0. Проверка наличия Git и Python (Python уже должен быть, раз скрипт запущен)
    if not check_command_exists("git"):
        sys.exit(1)
    if not check_command_exists(sys.executable): # Проверка текущего интерпретатора Python
        print(f"[ОШИБКА] Не удалось проверить текущий интерпретатор Python: {sys.executable}")
        sys.exit(1)


    # 1. Запросить/проверить путь к SSH-ключу
    ssh_key_path_to_use = args.ssh_key_path
    if not os.path.exists(ssh_key_path_to_use):
        print(f"[ПРЕДУПРЕЖДЕНИЕ] SSH-ключ не найден по стандартному пути или указанному: {ssh_key_path_to_use}")
        while True:
            custom_path = input("Пожалуйста, введите ПОЛНЫЙ путь к вашему приватному SSH-ключу (id_rsa): ").strip()
            if os.path.exists(custom_path) and os.path.isfile(custom_path):
                ssh_key_path_to_use = custom_path
                break
            else:
                print("[ОШИБКА] Файл не найден по указанному пути. Попробуйте снова.")
    
    print(f"[ИНФО] Используется SSH-ключ: {ssh_key_path_to_use}")

    # 2. Настроить SSH для Git
    if not configure_git_ssh(ssh_key_path_to_use):
        sys.exit(1)

    # 3. Клонировать основной приватный репозиторий
    if not clone_repository(args.main_repo_url, args.main_repo_dir):
        sys.exit(1)

    # 4. Установить зависимости основного проекта
    if not install_dependencies(args.main_repo_dir):
        print("[ПРЕДУПРЕЖДЕНИЕ] Установка зависимостей не удалась. Основной скрипт может работать некорректно.")
        # Решите, стоит ли прерывать: sys.exit(1)

    print("\n--- Начальная настройка завершена! ---")
    print(f"Основной проект автоматизации склонирован в: {args.main_repo_dir}")

    # 5. (Опционально) Запустить main_runner.py
    if not args.skip_main_runner:
        main_runner_path = os.path.join(args.main_repo_dir, "main_runner.py")
        if os.path.exists(main_runner_path):
            print(f"\n[ИНФО] Попытка запуска основного скрипта: {main_runner_path}")
            print("---------------------------------------------------------------")
            try:
                # Запускаем main_runner.py. Он должен сам проверять права администратора, если нужно.
                # Для Windows может потребоваться shell=True, если main_runner.py делает что-то специфичное для консоли.
                subprocess.run([sys.executable, main_runner_path], check=True, cwd=args.main_repo_dir, shell=(platform.system() == "Windows"))
            except subprocess.CalledProcessError as e:
                print(f"[ОШИБКА] Ошибка при выполнении main_runner.py: {e}")
            except Exception as e:
                print(f"[ОШИБКА] Непредвиденная ошибка при запуске main_runner.py: {e}")
        else:
            print(f"[ПРЕДУПРЕЖДЕНИЕ] Файл main_runner.py не найден в '{args.main_repo_dir}'. Пропуск запуска.")
    else:
        print("\n[ИНФО] Пропуск запуска main_runner.py согласно параметру --skip-main-runner.")
        print(f"Для запуска вручную: cd {args.main_repo_dir} && python main_runner.py")

if __name__ == "__main__":
    # Этот скрипт сам по себе может не требовать прав администратора,
    # но main_runner.py, который он запускает, может их потребовать.
    main()