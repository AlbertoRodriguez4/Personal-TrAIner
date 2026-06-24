"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.UpdateBodyAnalysisRecordDto = void 0;
const mapped_types_1 = require("@nestjs/mapped-types");
const create_body_analysis_record_dto_1 = require("./create-body-analysis-record.dto");
class UpdateBodyAnalysisRecordDto extends (0, mapped_types_1.PartialType)(create_body_analysis_record_dto_1.CreateBodyAnalysisRecordDto) {
}
exports.UpdateBodyAnalysisRecordDto = UpdateBodyAnalysisRecordDto;
