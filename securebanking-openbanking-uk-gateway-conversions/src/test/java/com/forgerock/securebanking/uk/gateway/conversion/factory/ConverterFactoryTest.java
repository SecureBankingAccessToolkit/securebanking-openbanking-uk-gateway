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
package com.forgerock.securebanking.uk.gateway.conversion.factory;

import com.forgerock.securebanking.openbanking.uk.common.api.meta.obie.OBVersion;
import com.forgerock.securebanking.openbanking.uk.common.api.meta.share.IntentType;
import com.forgerock.securebanking.uk.gateway.conversion.converters.account.AccountAccessIntentConverter;
import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

/**
 * Unit tests for {@link com.forgerock.securebanking.uk.gateway.conversion.factory.ConverterFactory}
 */
public class ConverterFactoryTest {
    @Test
    public void shouldGetAccountConverterInstance() {
        assertThat(ConverterFactory.getConverter(IntentType.ACCOUNT_ACCESS_CONSENT, OBVersion.v3_1_8))
                .isExactlyInstanceOf(AccountAccessIntentConverter.class);
    }

    @Test
    public void couldNotFindTheConverter() {
        assertThatThrownBy(() ->
                ConverterFactory.getConverter(IntentType.ACCOUNT_ACCESS_CONSENT, OBVersion.v3_1)
        ).isExactlyInstanceOf(RuntimeException.class)
                .hasMessageContaining("Couldn't find the %s converter for version %s", IntentType.ACCOUNT_ACCESS_CONSENT.name(), OBVersion.v3_1.name());
    }

    @Test
    public void couldNotIdentifyTheIntentType() {
        assertThatThrownBy(() ->
                ConverterFactory.getConverter(IntentType.ACCOUNT_REQUEST, OBVersion.v3_1)
        ).isExactlyInstanceOf(RuntimeException.class)
                .hasMessageContaining("Couldn't identify the intent type %s", IntentType.ACCOUNT_REQUEST);

    }
}
