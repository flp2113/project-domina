class_name DebugFlags
extends RefCounted

# Chave geral dos atalhos de debug. Ponha false antes de exportar a build:
#   B  (mapa)        -> abre a casa de apostas direto
#   E  (mapa)        -> abre um evento "?" direto
#   teclas no duelo  -> DebugRuleConsole (vencer, perder, alternar leis...)
# Continua exigindo build de debug onde já exigia (OS.is_debug_build()).
const SHORTCUTS: bool = false
