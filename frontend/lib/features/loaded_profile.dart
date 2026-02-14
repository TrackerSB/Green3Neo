/* Due to conflicting FRB mirror defitions this class converts all duplicated
 * backend_api variants to the considered "original" mirror provided by the
 * other APIs
 */
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:get_it/get_it.dart';
import 'package:green3neo/features/feature.dart';
import 'package:green3neo/interface/backend_api/api.dart' as backend_api;
import 'package:green3neo/interface/backend_api/api/profile.dart';
import 'package:green3neo/interface/database_api/api.dart';
import 'package:green3neo/interface/sepa_api/api.dart';

part 'loaded_profile.freezed.dart';

@Freezed()
class LoadedProfile with _$LoadedProfile {
  @override
  Creditor? creditor;
  @override
  ConnectionDescription? connection;

  LoadedProfile._create({
    @Default(null) this.creditor,
    @Default(null) this.connection,
  });

  Future<void> save() async {
    final backend_api.Creditor? mirroredCreditor = (creditor == null)
        ? null
        : backend_api.Creditor(
            name: backend_api.Name(value: creditor!.name.value),
            id: backend_api.CreditorID(value: creditor!.id.value),
            iban: backend_api.IBAN(value: creditor!.iban.value));

    final backend_api.ConnectionDescription? mirroredConnection =
        (connection == null)
            ? null
            : backend_api.ConnectionDescription(
                host: connection!.host,
                port: connection!.port,
                user: connection!.user,
                password: connection!.password,
                name: connection!.name,
              );

    await saveProfile(
      profile: Profile(
        creditor: mirroredCreditor,
        connection: mirroredConnection,
      ),
    );

    final getIt = GetIt.instance;
    getIt.resetLazySingleton<LoadedProfile>();
  }
}

class LoadedProfileFeature implements Feature {
  @override
  void register() {
    final getIt = GetIt.instance;
    getIt.registerLazySingletonAsync<LoadedProfile>(() async {
      return await loadProfile().then((final Profile? profile) {
        if (profile == null) {
          return LoadedProfile._create();
        }

        final backend_api.Creditor? mirroredCreditor = profile.creditor;

        final Creditor? creditor = (mirroredCreditor == null)
            ? null
            : Creditor(
                iban: IBAN(value: mirroredCreditor.iban.value),
                id: CreditorID(value: mirroredCreditor.id.value),
                name: Name(value: mirroredCreditor.name.value),
              );

        final backend_api.ConnectionDescription? mirroredConnection =
            profile.connection;

        final ConnectionDescription? connection = (mirroredConnection == null)
            ? null
            : ConnectionDescription(
                host: mirroredConnection.host,
                port: mirroredConnection.port,
                user: mirroredConnection.user,
                password: mirroredConnection.password,
                name: mirroredConnection.name,
              );

        return LoadedProfile._create(
          creditor: creditor,
          connection: connection,
        );
      });
    });
  }
}
