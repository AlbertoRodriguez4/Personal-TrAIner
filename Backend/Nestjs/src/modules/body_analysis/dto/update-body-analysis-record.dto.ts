import { PartialType } from '@nestjs/mapped-types';
import { CreateBodyAnalysisRecordDto } from './create-body-analysis-record.dto';

export class UpdateBodyAnalysisRecordDto extends PartialType(CreateBodyAnalysisRecordDto) {}
