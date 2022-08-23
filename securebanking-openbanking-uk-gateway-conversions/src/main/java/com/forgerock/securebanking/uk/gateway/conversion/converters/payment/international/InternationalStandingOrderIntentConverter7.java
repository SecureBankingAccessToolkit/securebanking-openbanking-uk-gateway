/*
 * Copyright © 2020-2022 ForgeRock AS (obst@forgerock.com)
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
package com.forgerock.securebanking.uk.gateway.conversion.converters.payment.international;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.forgerock.securebanking.uk.gateway.conversion.converters.GenericIntentConverter;
import com.forgerock.securebanking.uk.gateway.utils.jackson.GenericConverterMapper;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import uk.org.openbanking.datamodel.payment.OBWriteInternationalStandingOrderConsentResponse7;

public class InternationalStandingOrderIntentConverter7 extends GenericIntentConverter<OBWriteInternationalStandingOrderConsentResponse7> {

    private static final Logger logger = LoggerFactory.getLogger(InternationalStandingOrderIntentConverter7.class);

    public InternationalStandingOrderIntentConverter7() {
        super(InternationalStandingOrderIntentConverter7::convert);
    }

    private static OBWriteInternationalStandingOrderConsentResponse7 convert(String jsonString) {
        try {
            logger.debug("Payload to be converted\n {}", jsonString);
            return GenericConverterMapper.getMapper().readValue(jsonString, OBWriteInternationalStandingOrderConsentResponse7.class);
        } catch (JsonProcessingException e) {
            logger.trace("The following RuntimeException was caught : ", e);
            throw new RuntimeException(e);
        }
    }
}
