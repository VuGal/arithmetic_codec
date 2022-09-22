#ifndef _COMMONS_H
    #include "Commons.h"
#endif /* _COMMONS_H */


#ifndef _ADAPTIVE_MODEL_H
#define _ADAPTIVE_MODEL_H


void AdaptiveModelResetFrequencies(StatisticalModel *model);

void AdaptiveModelUpdateSymbolFrequency(StatisticalModel *model, uint16_t symbol);


#endif /* _ADAPTIVE_MODEL_H */
