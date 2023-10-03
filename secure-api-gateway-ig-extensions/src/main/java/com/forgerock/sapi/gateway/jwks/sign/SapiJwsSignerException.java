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
package com.forgerock.sapi.gateway.jwks.sign;

public class SapiJwsSignerException extends Exception {

    private static final long serialVersionUID = 1L;

    public SapiJwsSignerException(String message) {
        super(message);
    }

    public SapiJwsSignerException(String message, Throwable cause) {
        super(message, cause);
    }

    public SapiJwsSignerException(Throwable cause) {
        super(cause);
    }
}
