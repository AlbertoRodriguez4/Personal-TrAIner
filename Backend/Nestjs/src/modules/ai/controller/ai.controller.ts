import { Body, Controller, Post } from '@nestjs/common';

import { AiChatDto } from '../dto/chat.dto';
import {
  BodyCompositionDto,
  ClinicalDocumentDto,
  ClinicalManualDto,
  FoodEstimateDto,
  FoodSuggestionsDto,
  PhysiqueAnalysisDto,
} from '../dto/analysis.dto';
import { AiService } from '../service/ai.service';

@Controller('ai')
export class AiController {
  constructor(private readonly aiService: AiService) {}

  @Post('chat')
  chat(@Body() dto: AiChatDto) {
    return this.aiService.chat(dto);
  }

  /// Sube un PDF/imagen de analítica: el servicio Python lo extrae, lo
  /// contrasta contra MedlinePlus (NIH/NLM) y los rangos de referencia, redacta
  /// el resumen y lo persiste. Devuelve el informe ya guardado.
  @Post('clinical-report')
  analyzeClinicalDocument(@Body() dto: ClinicalDocumentDto) {
    return this.aiService.analyzeClinicalDocument(dto);
  }

  /// Valores tecleados a mano: reciben el mismo contraste y resumen que un
  /// documento, no se guardan tal cual.
  @Post('clinical-manual')
  analyzeClinicalManual(@Body() dto: ClinicalManualDto) {
    return this.aiService.analyzeClinicalManual(dto);
  }

  /// Composición corporal tecleada a mano (DEXA, bioimpedancia, báscula). Pasa
  /// por el servicio Python — aunque no haya modelo de por medio — para que las
  /// tablas de referencia con las que se clasifica vivan en un solo sitio y la
  /// app enseñe los mismos tramos que después lee Pulso.
  @Post('body-composition')
  registerBodyComposition(@Body() dto: BodyCompositionDto) {
    return this.aiService.registerBodyComposition(dto);
  }

  @Post('physique-analysis')
  analyzePhysique(@Body() dto: PhysiqueAnalysisDto) {
    return this.aiService.analyzePhysique(dto);
  }

  /// Registro manual de comida (nutricion, sin foto): nombre + cantidad
  /// (gramos o referencia) -> macros escalados. No pasa por ningún modelo ni
  /// guarda nada, igual que body-composition — ver AiService.estimateFood.
  @Post('nutrition/food-estimate')
  estimateFood(@Body() dto: FoodEstimateDto) {
    return this.aiService.estimateFood(dto);
  }

  /// Autocompletado del catálogo local mientras el usuario escribe el nombre
  /// del alimento en el registro manual.
  @Post('nutrition/food-suggestions')
  suggestFoods(@Body() dto: FoodSuggestionsDto) {
    return this.aiService.suggestFoods(dto);
  }
}
