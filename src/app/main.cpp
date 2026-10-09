// Pegasus Frontend
// Copyright (C) 2017-2020  Mátyás Mustoha
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program. If not, see <http://www.gnu.org/licenses/>.


#include "backend/Backend.h"
#include "backend/Paths.h"
#include "backend/platform/TerminalKbd.h"

#include <QCommandLineParser>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QGuiApplication>
#include <QIcon>
#include <QSettings>
#include <QtPlugin>

#ifdef Q_OS_ANDROID
#include "backend/platform/AndroidHelpers.h"
#include <QEventLoop>
#include <QTimer>
#include <QtAndroidExtras/QAndroidJniObject>
#endif


#ifdef WITH_APNG_SUPPORT
Q_IMPORT_PLUGIN(ApngImagePlugin)
#endif


backend::CliArgs handle_cli_args(QGuiApplication&);
bool request_runtime_permissions();
bool portable_txt_present();
void p7_first_run_setup();

int main(int argc, char *argv[])
{
    Q_INIT_RESOURCE(frontend);
    Q_INIT_RESOURCE(themes);
    Q_INIT_RESOURCE(qmlutils);
#ifdef PEGASUS_USING_CMAKE  // TODO: Unify the build system
    Q_INIT_RESOURCE(assets);
    Q_INIT_RESOURCE(locales);
    Q_INIT_RESOURCE(qmlutils_qmlcache);
    Q_INIT_RESOURCE(frontend_qmlcache);
    Q_INIT_RESOURCE(themes_qmlcache);
#endif

    TerminalKbd::on_startup();

    QCoreApplication::addLibraryPath(QStringLiteral("lib/plugins"));
    QCoreApplication::addLibraryPath(QStringLiteral("lib"));
    QSettings::setDefaultFormat(QSettings::IniFormat);

    QGuiApplication app(argc, argv);
    app.setApplicationName(QStringLiteral("pegasus-frontend"));
    app.setApplicationVersion(QStringLiteral(GIT_REVISION));
    app.setOrganizationName(QStringLiteral("pegasus-frontend"));
    app.setOrganizationDomain(QStringLiteral("pegasus-frontend.org"));
    app.setWindowIcon(QIcon(QStringLiteral(":/icon.png")));

    qWarning("P7: app iniciado, verificando permissao de arquivos");
    if (!request_runtime_permissions()) {
        qWarning("P7: sem permissao de arquivos, encerrando");
        return 1;
    }
    qWarning("P7: permissao ok");

    p7_first_run_setup();
    qWarning("P7: pastas prontas, iniciando o hub");

    backend::CliArgs cli_args = handle_cli_args(app);
    cli_args.portable |= portable_txt_present();

    backend::Backend backend(cli_args);
    backend.start();

    return app.exec();
}

bool request_runtime_permissions()
{
#ifdef Q_OS_ANDROID
    if (android::has_external_storage_access())
        return true;
    qWarning("P7: aguardando a permissao de arquivos");

    // P7 Station: o Android abriu a tela "Acesso a todos os arquivos". Antes o app encerrava aqui
    // e ficava uma tela branca ao voltar; agora ele espera a permissão e segue normalmente.
    QEventLoop wait_loop;
    QTimer poll;
    QObject::connect(&poll, &QTimer::timeout, [&wait_loop](){
        const bool granted = QAndroidJniObject::callStaticMethod<jboolean>(
            "org/pegasus_frontend/android/MainActivity", "hasAllStorageAccess");
        if (granted)
            wait_loop.quit();
    });
    poll.start(600);
    wait_loop.exec();
    qWarning("P7: permissao de arquivos concedida");
    const bool ok = android::has_external_storage_access();
    qWarning("P7: verificacao final da permissao: %d", ok ? 1 : 0);
    return ok;
#endif

    return true;
}


bool portable_txt_present()
{
#ifdef Q_OS_ANDROID
    // NOTE: On Android, the executable location is not generally accessible
    return false;
#else
    const QString path = paths::app_dir_path() + QStringLiteral("/portable.txt");
    return QFileInfo::exists(path);
#endif
}


QCommandLineOption add_cli_option(QCommandLineParser& parser, const QString& name, const QString& desc)
{
    QCommandLineOption arg(name, desc);
    parser.addOption(arg);
    return arg;
}

backend::CliArgs handle_cli_args(QGuiApplication& app)
{
#define CMDMSG QStringLiteral

    QCommandLineParser argparser;
    argparser.setApplicationDescription(CMDMSG(
        "\nPegasus is a graphical frontend for browsing your game library (especially\n"
        "retro games) and launching them from one place. It's focusing on customization,\n"
        "cross platform support (including embedded devices) and high performance."));

    const QCommandLineOption arg_portable = add_cli_option(argparser,
        QStringLiteral("portable"),
        CMDMSG("Do not read or write config files outside the program's directory"));

    const QCommandLineOption arg_silent = add_cli_option(argparser,
        QStringLiteral("silent"),
        CMDMSG("Do not print log messages to the terminal"));

    const QCommandLineOption arg_menu_reboot = add_cli_option(argparser,
        QStringLiteral("disable-menu-reboot"),
        CMDMSG("Hides the system reboot entry in the main menu"));

    const QCommandLineOption arg_menu_shutdown = add_cli_option(argparser,
        QStringLiteral("disable-menu-shutdown"),
        CMDMSG("Hides the system shutdown entry in the main menu"));

    const QCommandLineOption arg_menu_suspend = add_cli_option(argparser,
        QStringLiteral("disable-menu-suspend"),
        CMDMSG("Hides the system suspend entry in the main menu"));

    const QCommandLineOption arg_menu_appclose = add_cli_option(argparser,
        QStringLiteral("disable-menu-appclose"),
        CMDMSG("Hides the closing Pegasus entry in the main menu"));

    const QCommandLineOption arg_menu_settings = add_cli_option(argparser,
        QStringLiteral("disable-menu-settings"),
        CMDMSG("Hides the settings menu entry in the main menu"));

    const QCommandLineOption arg_menu_kiosk = add_cli_option(argparser,
        QStringLiteral("kiosk"),
        CMDMSG("Alias for:\n"
               "--disable-menu-reboot\n"
               "--disable-menu-shutdown\n"
               "--disable-menu-appclose\n"
               "--disable-menu-settings"));

    const QCommandLineOption arg_gamepad_autoconfig = add_cli_option(argparser,
        QStringLiteral("disable-gamepad-autoconfig"),
        CMDMSG("Disables the automatic layout detection for connected gamepads.\n"
               "When you connect a gamepad, Pegasus tries to guess its button and axis layout "
               "automatically based on a list of known devices. Unfortunately this doesn't seem "
               "to work perfectly with some platforms and devices (eg. arcades), in which case "
               "you can disable this feature here."));

    argparser.addHelpOption();
    argparser.addVersionOption();
    argparser.process(app); // may quit!

    backend::CliArgs args;
    args.portable = argparser.isSet(arg_portable);
    args.silent = argparser.isSet(arg_silent);
    args.enable_menu_appclose = !(argparser.isSet(arg_menu_kiosk) || argparser.isSet(arg_menu_appclose));
    args.enable_menu_settings = !(argparser.isSet(arg_menu_kiosk) || argparser.isSet(arg_menu_settings));
    args.enable_gamepad_autoconfig = !argparser.isSet(arg_gamepad_autoconfig);
#ifdef Q_OS_ANDROID
    args.enable_menu_shutdown = false;
    args.enable_menu_reboot = false;
#else
    args.enable_menu_shutdown = !(argparser.isSet(arg_menu_kiosk) || argparser.isSet(arg_menu_shutdown));
    args.enable_menu_reboot = !(argparser.isSet(arg_menu_kiosk) || argparser.isSet(arg_menu_reboot));
#endif
#if defined(Q_OS_ANDROID) || defined(Q_OS_WINDOWS) || defined(Q_OS_MAC)
    args.enable_menu_suspend = false;
#else
    args.enable_menu_suspend = !(argparser.isSet(arg_menu_kiosk) || argparser.isSet(arg_menu_suspend));
#endif
    return args;

#undef CMDMSG
}


// ---------------------------------------------------------------- P7 Station
// O tema gera o arquivo de consoles e emuladores (metadata.pegasus.txt) dentro da pasta
// "biblioteca" do app, a partir das pastas que ele acha ou que a pessoa escolhe.
// Aqui só garantimos que essa pasta existe e está registrada, e tiramos o arquivo fixo
// das versões antigas (pasta Jogos), que agora seria repetido.
void p7_first_run_setup()
{
#ifdef Q_OS_ANDROID
    const QString library_dir = paths::writableConfigDir() + QStringLiteral("/biblioteca");
    QDir().mkpath(library_dir);

    QFile meta(library_dir + QStringLiteral("/metadata.pegasus.txt"));
    if (!meta.exists() && meta.open(QIODevice::WriteOnly)) {
        meta.write("# P7STATION-GERADO v2\n");
        meta.close();
    }

    QFile old_meta(QStringLiteral("/storage/emulated/0/Jogos/metadata.pegasus.txt"));
    if (old_meta.open(QIODevice::ReadOnly)) {
        const bool ours = old_meta.read(32).startsWith("# P7STATION-AUTO");
        old_meta.close();
        if (ours) {
            old_meta.remove();
            qWarning("P7: arquivo antigo da pasta Jogos removido");
        }
    }

    QFile gamedirs(paths::writableConfigDir() + QStringLiteral("/game_dirs.txt"));
    QByteArray listed;
    if (gamedirs.open(QIODevice::ReadOnly)) {
        listed = gamedirs.readAll();
        gamedirs.close();
    }
    if (!listed.split('\n').contains(library_dir.toUtf8())
        && gamedirs.open(QIODevice::Append | QIODevice::Text)) {
        if (!listed.isEmpty() && !listed.endsWith('\n'))
            gamedirs.write("\n");
        gamedirs.write(library_dir.toUtf8() + "\n");
        gamedirs.close();
    }
#endif
}
