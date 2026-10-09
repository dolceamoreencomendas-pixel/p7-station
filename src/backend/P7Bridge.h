// P7 Station: ponte entre o tema e o sistema (pacotes instalados, pastas e arquivos).
#pragma once

#include <QObject>
#include <QStringList>
#include <QVariantList>


class P7Bridge : public QObject {
    Q_OBJECT

public:
    explicit P7Bridge(QObject* parent = nullptr);

    // nomes dos pacotes instalados no aparelho (para achar os emuladores)
    Q_INVOKABLE QStringList installedPackages() const;
    // emuladores de Switch da família yuzu instalados: [{ pkg, activity, label, updated }]
    Q_INVOKABLE QVariantList switchEmulators() const;
    // subpastas de uma pasta (sem as ocultas), em ordem alfabética
    Q_INVOKABLE QStringList subdirs(const QString& path) const;
    Q_INVOKABLE bool isDir(const QString& path) const;
    Q_INVOKABLE int countFiles(const QString& path, const QStringList& extensions) const;
    Q_INVOKABLE QString readText(const QString& path) const;
    Q_INVOKABLE bool writeText(const QString& path, const QString& text) const;
    // pasta onde fica o metadata.pegasus.txt gerado pelo tema
    Q_INVOKABLE QString libraryDir() const;
    // armazenamento interno (/storage/emulated/0)
    Q_INVOKABLE QString storageRoot() const;
    // controles conectados: [{ name, hasBattery, level (0-100, -1 = sem dado), charging, full }]
    Q_INVOKABLE QVariantList controllers() const;
    // capa de um jogo de Switch (ícone da eShop): pelo ID no nome do arquivo ou pelo título; "" se não achar
    Q_INVOKABLE QString switchCover(const QString& title, const QString& filePath) const;

    // abertura animada: pendente até ser mostrada uma vez desde que o app abriu (não repete depois de cada jogo)
    Q_INVOKABLE bool introPending() const;
    Q_INVOKABLE void introDone();
};
