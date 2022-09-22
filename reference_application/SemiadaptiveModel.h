#ifndef _COMMONS_H
    #include "Commons.h"
#endif /* _COMMONS_H */


#ifndef _SEMIADAPTIVE_MODEL_H
#define _SEMIADAPTIVE_MODEL_H


void SemiadaptiveModelEncoderInitializeFrequencies(StatisticalModel *model, char *inputFilePath);

void SemiadaptiveModelDecoderInitializeFrequencies(StatisticalModel *model, char *inputFilePath);

void SemiadaptiveModelUpdateSymbolFrequency(StatisticalModel *model, uint16_t symbol);


#endif /* _SEMIADAPTIVE_MODEL_H */
