#include <QApplication>
#include <QLabel>
#include <QMainWindow>

int main(int argc, char* argv[])
{
    QApplication app(argc, argv);
    app.setApplicationName("OpenShape");
    app.setApplicationVersion("0.1.0");
    app.setOrganizationName("OpenShape");

    QMainWindow window;
    window.setWindowTitle("OpenShape");
    window.resize(1280, 800);

    auto* placeholder = new QLabel("OpenShape — M1 Foundation\nOCCT linked. Viewport coming in M1 next steps.", &window);
    placeholder->setAlignment(Qt::AlignCenter);
    window.setCentralWidget(placeholder);

    window.show();
    return app.exec();
}
