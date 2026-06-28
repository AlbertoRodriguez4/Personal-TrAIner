"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.DailySummaryResponseDto = exports.UltimaSesionDto = exports.MacroCumplimientoDto = exports.DailySummaryDto = void 0;
class DailySummaryDto {
    kcal;
    proteinas_g;
    carbohidratos_g;
    grasas_g;
}
exports.DailySummaryDto = DailySummaryDto;
class MacroCumplimientoDto {
    objetivo;
    consumido;
    porcentaje;
    cumplido;
}
exports.MacroCumplimientoDto = MacroCumplimientoDto;
class UltimaSesionDto {
    id;
    fecha_programada;
    tipo_entrenamiento;
    estado;
    fecha_finalizacion;
}
exports.UltimaSesionDto = UltimaSesionDto;
class DailySummaryResponseDto {
    usuario_id;
    fecha;
    objetivos;
    consumido_hoy;
    cumplimiento;
    objetivos_cumplidos;
    ultima_sesion;
    rutinas_count;
    metas_calculadas_automaticamente;
}
exports.DailySummaryResponseDto = DailySummaryResponseDto;
