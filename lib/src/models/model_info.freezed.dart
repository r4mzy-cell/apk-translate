// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'model_info.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ModelInfo {

 String get id; String get name; ModelType get type; String get language; String? get version; int get sizeBytes; String? get checksum; String? get localPath; bool get isDownloaded; bool get isActive; DateTime? get downloadedAt; DateTime? get updatedAt;
/// Create a copy of ModelInfo
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ModelInfoCopyWith<ModelInfo> get copyWith => _$ModelInfoCopyWithImpl<ModelInfo>(this as ModelInfo, _$identity);

  /// Serializes this ModelInfo to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as ModelInfo;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ModelInfo&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.type, _this.type) || other.type == _this.type)&&(identical(other.language, _this.language) || other.language == _this.language)&&(identical(other.version, _this.version) || other.version == _this.version)&&(identical(other.sizeBytes, _this.sizeBytes) || other.sizeBytes == _this.sizeBytes)&&(identical(other.checksum, _this.checksum) || other.checksum == _this.checksum)&&(identical(other.localPath, _this.localPath) || other.localPath == _this.localPath)&&(identical(other.isDownloaded, _this.isDownloaded) || other.isDownloaded == _this.isDownloaded)&&(identical(other.isActive, _this.isActive) || other.isActive == _this.isActive)&&(identical(other.downloadedAt, _this.downloadedAt) || other.downloadedAt == _this.downloadedAt)&&(identical(other.updatedAt, _this.updatedAt) || other.updatedAt == _this.updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as ModelInfo;
  return Object.hash(runtimeType,_this.id,_this.name,_this.type,_this.language,_this.version,_this.sizeBytes,_this.checksum,_this.localPath,_this.isDownloaded,_this.isActive,_this.downloadedAt,_this.updatedAt);
}

@override
String toString() {
  final _this = this as ModelInfo;
  return 'ModelInfo(id: ${_this.id}, name: ${_this.name}, type: ${_this.type}, language: ${_this.language}, version: ${_this.version}, sizeBytes: ${_this.sizeBytes}, checksum: ${_this.checksum}, localPath: ${_this.localPath}, isDownloaded: ${_this.isDownloaded}, isActive: ${_this.isActive}, downloadedAt: ${_this.downloadedAt}, updatedAt: ${_this.updatedAt})';
}


}

/// @nodoc
abstract mixin class $ModelInfoCopyWith<$Res>  {
  factory $ModelInfoCopyWith(ModelInfo value, $Res Function(ModelInfo) _then) = _$ModelInfoCopyWithImpl;
@useResult
$Res call({
 String id, String name, ModelType type, String language, String? version, int sizeBytes, String? checksum, String? localPath, bool isDownloaded, bool isActive, DateTime? downloadedAt, DateTime? updatedAt
});




}
/// @nodoc
class _$ModelInfoCopyWithImpl<$Res>
    implements $ModelInfoCopyWith<$Res> {
  _$ModelInfoCopyWithImpl(this._self, this._then);

  final ModelInfo _self;
  final $Res Function(ModelInfo) _then;

/// Create a copy of ModelInfo
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? type = null,Object? language = null,Object? version = freezed,Object? sizeBytes = null,Object? checksum = freezed,Object? localPath = freezed,Object? isDownloaded = null,Object? isActive = null,Object? downloadedAt = freezed,Object? updatedAt = freezed,}) {
  return _then(ModelInfo(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as ModelType,language: null == language ? _self.language : language // ignore: cast_nullable_to_non_nullable
as String,version: freezed == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as String?,sizeBytes: null == sizeBytes ? _self.sizeBytes : sizeBytes // ignore: cast_nullable_to_non_nullable
as int,checksum: freezed == checksum ? _self.checksum : checksum // ignore: cast_nullable_to_non_nullable
as String?,localPath: freezed == localPath ? _self.localPath : localPath // ignore: cast_nullable_to_non_nullable
as String?,isDownloaded: null == isDownloaded ? _self.isDownloaded : isDownloaded // ignore: cast_nullable_to_non_nullable
as bool,isActive: null == isActive ? _self.isActive : isActive // ignore: cast_nullable_to_non_nullable
as bool,downloadedAt: freezed == downloadedAt ? _self.downloadedAt : downloadedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [ModelInfo].
extension ModelInfoPatterns on ModelInfo {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ModelInfo value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ModelInfo() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ModelInfo value)  $default,){
final _that = this;
switch (_that) {
case _ModelInfo():
return $default(_that);}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ModelInfo value)?  $default,){
final _that = this;
switch (_that) {
case _ModelInfo() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  ModelType type,  String language,  String? version,  int sizeBytes,  String? checksum,  String? localPath,  bool isDownloaded,  bool isActive,  DateTime? downloadedAt,  DateTime? updatedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ModelInfo() when $default != null:
return $default(_that.id,_that.name,_that.type,_that.language,_that.version,_that.sizeBytes,_that.checksum,_that.localPath,_that.isDownloaded,_that.isActive,_that.downloadedAt,_that.updatedAt);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  ModelType type,  String language,  String? version,  int sizeBytes,  String? checksum,  String? localPath,  bool isDownloaded,  bool isActive,  DateTime? downloadedAt,  DateTime? updatedAt)  $default,) {final _that = this;
switch (_that) {
case _ModelInfo():
return $default(_that.id,_that.name,_that.type,_that.language,_that.version,_that.sizeBytes,_that.checksum,_that.localPath,_that.isDownloaded,_that.isActive,_that.downloadedAt,_that.updatedAt);}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  ModelType type,  String language,  String? version,  int sizeBytes,  String? checksum,  String? localPath,  bool isDownloaded,  bool isActive,  DateTime? downloadedAt,  DateTime? updatedAt)?  $default,) {final _that = this;
switch (_that) {
case _ModelInfo() when $default != null:
return $default(_that.id,_that.name,_that.type,_that.language,_that.version,_that.sizeBytes,_that.checksum,_that.localPath,_that.isDownloaded,_that.isActive,_that.downloadedAt,_that.updatedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ModelInfo implements ModelInfo {
  const _ModelInfo({required this.id, required this.name, required this.type, required this.language, this.version, required this.sizeBytes, this.checksum, this.localPath, required this.isDownloaded, required this.isActive, this.downloadedAt, this.updatedAt});
  factory _ModelInfo.fromJson(Map<String, dynamic> json) => _$ModelInfoFromJson(json);

@override final  String id;
@override final  String name;
@override final  ModelType type;
@override final  String language;
@override final  String? version;
@override final  int sizeBytes;
@override final  String? checksum;
@override final  String? localPath;
@override final  bool isDownloaded;
@override final  bool isActive;
@override final  DateTime? downloadedAt;
@override final  DateTime? updatedAt;

/// Create a copy of ModelInfo
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ModelInfoCopyWith<_ModelInfo> get copyWith => __$ModelInfoCopyWithImpl<_ModelInfo>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ModelInfoToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ModelInfo&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.type, type) || other.type == type)&&(identical(other.language, language) || other.language == language)&&(identical(other.version, version) || other.version == version)&&(identical(other.sizeBytes, sizeBytes) || other.sizeBytes == sizeBytes)&&(identical(other.checksum, checksum) || other.checksum == checksum)&&(identical(other.localPath, localPath) || other.localPath == localPath)&&(identical(other.isDownloaded, isDownloaded) || other.isDownloaded == isDownloaded)&&(identical(other.isActive, isActive) || other.isActive == isActive)&&(identical(other.downloadedAt, downloadedAt) || other.downloadedAt == downloadedAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,name,type,language,version,sizeBytes,checksum,localPath,isDownloaded,isActive,downloadedAt,updatedAt);
}

@override
String toString() {
    return 'ModelInfo(id: $id, name: $name, type: $type, language: $language, version: $version, sizeBytes: $sizeBytes, checksum: $checksum, localPath: $localPath, isDownloaded: $isDownloaded, isActive: $isActive, downloadedAt: $downloadedAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class _$ModelInfoCopyWith<$Res> implements $ModelInfoCopyWith<$Res> {
  factory _$ModelInfoCopyWith(_ModelInfo value, $Res Function(_ModelInfo) _then) = __$ModelInfoCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, ModelType type, String language, String? version, int sizeBytes, String? checksum, String? localPath, bool isDownloaded, bool isActive, DateTime? downloadedAt, DateTime? updatedAt
});




}
/// @nodoc
class __$ModelInfoCopyWithImpl<$Res>
    implements _$ModelInfoCopyWith<$Res> {
  __$ModelInfoCopyWithImpl(this._self, this._then);

  final _ModelInfo _self;
  final $Res Function(_ModelInfo) _then;

/// Create a copy of ModelInfo
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? type = null,Object? language = null,Object? version = freezed,Object? sizeBytes = null,Object? checksum = freezed,Object? localPath = freezed,Object? isDownloaded = null,Object? isActive = null,Object? downloadedAt = freezed,Object? updatedAt = freezed,}) {
  return _then(_ModelInfo(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as ModelType,language: null == language ? _self.language : language // ignore: cast_nullable_to_non_nullable
as String,version: freezed == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as String?,sizeBytes: null == sizeBytes ? _self.sizeBytes : sizeBytes // ignore: cast_nullable_to_non_nullable
as int,checksum: freezed == checksum ? _self.checksum : checksum // ignore: cast_nullable_to_non_nullable
as String?,localPath: freezed == localPath ? _self.localPath : localPath // ignore: cast_nullable_to_non_nullable
as String?,isDownloaded: null == isDownloaded ? _self.isDownloaded : isDownloaded // ignore: cast_nullable_to_non_nullable
as bool,isActive: null == isActive ? _self.isActive : isActive // ignore: cast_nullable_to_non_nullable
as bool,downloadedAt: freezed == downloadedAt ? _self.downloadedAt : downloadedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

// dart format on
