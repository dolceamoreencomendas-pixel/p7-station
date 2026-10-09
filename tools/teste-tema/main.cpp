// Roda o tema do P7 Station no computador (sem Android), com uma biblioteca de mentira,
// para tirar prints e gravar as animações. Usado só no teste automático (GitHub Actions).
#include <QGuiApplication>
#include <QQmlEngine>
#include <QQmlComponent>
#include <QQmlContext>
#include <QQuickView>
#include <QQuickItem>
#include <QKeyEvent>
#include <QDir>
#include <QDebug>
#include <QTimer>

class Driver : public QObject {
    Q_OBJECT
public:
    QQuickView *view = nullptr;
    QString out;
    Q_INVOKABLE void key(int k, int ms = 0) {
        QKeyEvent press(QEvent::KeyPress, k, Qt::NoModifier);
        QCoreApplication::sendEvent(view, &press);
        if (ms <= 0) {
            QKeyEvent rel(QEvent::KeyRelease, k, Qt::NoModifier);
            QCoreApplication::sendEvent(view, &rel);
        }
    }
    Q_INVOKABLE void release(int k) {
        QKeyEvent rel(QEvent::KeyRelease, k, Qt::NoModifier);
        QCoreApplication::sendEvent(view, &rel);
    }
    Q_INVOKABLE void shot(const QString &name) {
        QImage img = view->grabWindow();
        img.save(out + "/" + name + ".png");
    }
    Q_INVOKABLE void quit() { QCoreApplication::exit(0); }
};

int main(int argc, char *argv[]) {
    QGuiApplication app(argc, argv);
    QString dir = QDir(QCoreApplication::applicationDirPath()).absolutePath();
    QString here = argc > 1 ? argv[1] : dir;
    Driver driver;
    driver.out = argc > 2 ? argv[2] : here + "/saida";
    QDir().mkpath(driver.out);

    QQmlEngine engine;
    QQmlComponent mocks(&engine, QUrl::fromLocalFile(here + "/mocks.qml"));
    QObject *m = mocks.create();
    if (!m) { qWarning() << mocks.errors(); return 1; }
    engine.rootContext()->setContextProperty("api", m->property("api").value<QObject *>());
    engine.rootContext()->setContextProperty("Internal", m->property("internal").value<QObject *>());
    engine.rootContext()->setContextProperty("P7", m->property("p7").value<QObject *>());
    engine.rootContext()->setContextProperty("driver", &driver);
    engine.rootContext()->setContextProperty("mocks", m);

    QQuickView view(&engine, nullptr);
    driver.view = &view;
    view.setFlags(Qt::FramelessWindowHint);
    view.setResizeMode(QQuickView::SizeRootObjectToView);
    view.resize(1600, 1068);
    view.setPosition(0, 0);
    view.setSource(QUrl::fromLocalFile(here + "/roteiro.qml"));
    if (view.status() != QQuickView::Ready) { qWarning() << view.errors(); return 1; }
    view.show();
    view.requestActivate();
    // sem gerenciador de janelas a janela pode não ficar ativa sozinha: insiste até ficar
    QTimer *t = new QTimer(&view);
    QObject::connect(t, &QTimer::timeout, [&view, t]() {
        if (view.isActive()) { t->stop(); return; }
        view.requestActivate();
    });
    t->start(300);
    return app.exec();
}
#include "main.moc"
