/*
 *     Copyright (C) 2026 Stemkara Authors
 *     Copyright (C) 2026 Valeri Gokadze
 *
 *     Stemkara is free software: you can redistribute it and/or modify
 *     it under the terms of the GNU General Public License as published by
 *     the Free Software Foundation, either version 3 of the License, or
 *     (at your option) any later version.
 *
 *     Stemkara is distributed in the hope that it will be useful,
 *     but WITHOUT ANY WARRANTY; without even the implied warranty of
 *     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *     GNU General Public License for more details.
 *
 *     You should have received a copy of the GNU General Public License
 *     along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

import 'package:flutter/widgets.dart';
import 'package:musify/localization/app_localizations.dart';

extension ContextX on BuildContext {
  AppLocalizations? get l10n => AppLocalizations.of(this);
}
