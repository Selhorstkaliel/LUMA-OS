/* Apresentação exibida durante a instalação do Luma. SPDX-License-Identifier: GPL-3.0-or-later */
import QtQuick 2.0;
import calamares.slideshow 1.0;

Presentation
{
    id: presentation

    Slide {
        Image {
            id: logo
            source: "luma-logo.svg"
            sourceSize.width: 160; sourceSize.height: 160
            width: 160; height: 160
            anchors.centerIn: parent
        }
        Text {
            anchors.horizontalCenter: logo.horizontalCenter
            anchors.top: logo.bottom
            anchors.topMargin: 24
            text: "Instalando o Luma.<br/>O restante é automático e leva alguns minutos. " +
                  "Não desligue o computador."
            wrapMode: Text.WordWrap
            width: 600
            horizontalAlignment: Text.Center
        }
    }
}
