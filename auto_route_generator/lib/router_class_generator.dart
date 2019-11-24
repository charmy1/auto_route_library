import 'package:auto_route_generator/route_config_builder.dart';
import 'package:auto_route_generator/string_utils.dart';

class RouterClassGenerator {
  final List<RouteConfig> routes;

  final StringBuffer _stringBuffer = StringBuffer();

  RouterClassGenerator(this.routes);

  // helper functions
  void _write(Object obj) => _stringBuffer.write(obj);

  void _writeln([Object obj]) => _stringBuffer.writeln(obj);

  void _newLine() => _stringBuffer.writeln();

  String generate() {
    _generateImports();
    _writeln("\nclass Router {");
    _generateRouteNames();
    _generateRouteGeneratorFunction();

    _generateNeededFunctions();

    // close router class
    _writeln("}");
    _generateArgumentHolders();
    return _stringBuffer.toString();
  }

  void _generateImports() {
    // write route imports
    final imports = List<String>();
    imports.add("'package:flutter/material.dart'");
    routes.forEach((r) {
      imports.add(r.import);
      if (r.transitionBuilder != null) imports.add(r.transitionBuilder.import);
      if (r.parameters != null) {
        r.parameters.forEach((param) {
          if (param.import != null) imports.add(param.import);
        });
      }
    });
    imports.toSet().forEach((import) => _writeln("import $import;"));
  }

  void _generateRouteNames() {
    _newLine();
    routes.forEach((r) {
      if (r.initial != null && r.initial)
        _writeln(" static const initialRoute = '/';");
      else {
        final routeName = _generateRouteName(r);
        return _writeln(" static const $routeName = '/$routeName';");
      }
    });
  }

  String _generateRouteName(RouteConfig r) {
    String routeName = _routeNameFromClassName(r.className);
    if (r.name != null) {
      final strippedName = r.name.replaceAll(r"\s", "");
      if (strippedName.isNotEmpty) routeName = strippedName;
    }
    return routeName;
  }

  String _routeNameFromClassName(String className) {
    final name = toLowerCamelCase(className);
    return "${name}Route";
  }

  void _generateRouteGeneratorFunction() {
    _newLine();
    _writeln("static Route<dynamic> onGenerateRoute(RouteSettings settings) {");
    _writeln("final args = settings.arguments;");
    _writeln("switch (settings.name) {");

    routes.forEach((r) => generateRoute(r));

    // build unknown route error page if route is not found
    _writeln("default: return _unknownRoutePage(settings.name);");
    // close switch case
    _writeln("}");
    _newLine();

    // close onGenerateRoute function
    _writeln("}");
  }

  void generateRoute(RouteConfig r) {
    final caseName = (r.initial != null && r.initial) ? "initialRoute" : _generateRouteName(r);
    _writeln("case $caseName:");

    StringBuffer constructorParams = StringBuffer("");

    if (r.parameters != null && r.parameters.isNotEmpty) {
      if (r.parameters.length == 1) {
        final param = r.parameters[0];

        // show an error page if passed args are not the same as declared args
        _writeln("if(_hasInvalidArgs<${param.type}>(args))");
        _writeln("return _misTypedArgsRoute<${param.type}>(args);");

        _writeln("final typedArgs = args as ${param.type};");

        if (param.isPositional)
          constructorParams.write("typedArgs");
        else {
          constructorParams.write("${param.name}: typedArgs");
          if (param.defaultValueCode != null) constructorParams.write(" ?? ${param.defaultValueCode}");
        }
      } else {
        // show an error page  if passed args are not the same as declared args
        _writeln("if(_hasInvalidArgs<${r.className}Arguments>(args))");
        _writeln("return _misTypedArgsRoute<${r.className}Arguments>(args);");

        _writeln("final typedArgs = args as ${r.className}Arguments ?? ${r.className}Arguments();");

        r.parameters.asMap().forEach((i, param) {
          if (param.isPositional)
            constructorParams.write("typedArgs.${param.name}");
          else
            constructorParams.write("${param.name}:typedArgs.${param.name}");

          if (i != r.parameters.length - 1) constructorParams.write(",");
        });
      }
    }

    final widget = "${r.className}(${constructorParams.toString()})";
    if (r.transitionBuilder == null) {
      _write("return MaterialPageRoute(builder: (_) => $widget, settings: settings,");
      if (r.fullscreenDialog != null) _write("fullscreenDialog:${r.fullscreenDialog.toString()},");
      if (r.maintainState != null) _write("maintainState:${r.maintainState.toString()},");
    } else {
      _write("return PageRouteBuilder(pageBuilder: (ctx, animation, secondaryAnimation) => $widget, settings: settings,");
      if (r.maintainState != null) _write(",maintainState:${r.maintainState.toString()}");
      _write("transitionsBuilder: ${r.transitionBuilder.name},");
      if (r.durationInMilliseconds != null) _write("transitionDuration: Duration(milliseconds: ${r.durationInMilliseconds}),");
    }
    _writeln(");");
  }

  void _generateArgumentHolders() {
    final routesWithArgsHolders = routes.where((r) => r.parameters != null && r.parameters.length > 1);
    if (routesWithArgsHolders.isNotEmpty) _writeln("\n//----------------------------------------------");
    routesWithArgsHolders.forEach((r) {
      _generateArgsHolder(r);
    });
  }

  void _generateArgsHolder(RouteConfig r) {
    _writeln("//${r.className} arguments holder class");
    final argsClassName = "${r.className}Arguments";

    _writeln("class $argsClassName{");
    r.parameters.forEach((param) {
      _writeln("final ${param.type} ${param.name};");
    });

    _writeln("$argsClassName({");
    r.parameters.asMap().forEach((i, param) {
      _write("this.${param.name}");
      if (param.defaultValueCode != null) _write(" = ${param.defaultValueCode}");
      if (i != r.parameters.length - 1) _write(",");
    });
    _writeln("});");

    _writeln("}");
  }

  void _generateNeededFunctions() {
    _writeln("\nstatic PageRoute _unknownRoutePage(String routeName) => "
        "MaterialPageRoute(builder: (ctx) => Scaffold(body: Container("
        "color: Colors.redAccent,width: MediaQuery.of(ctx).size.width,"
        "padding: const EdgeInsets.symmetric(horizontal: 16.0),"
        "child: Column(mainAxisAlignment: MainAxisAlignment.center,children: <Widget>["
        "Text('Route name \$routeName is not found!', textAlign: TextAlign.center,),"
        "const SizedBox(height: 16.0),"
        "OutlineButton.icon(label: Text('Back'), icon: Icon(Icons.arrow_back), onPressed: () => Navigator.of(ctx).pop(),)"
        "],),),),);");

    _writeln("static bool _hasInvalidArgs<T>(Object args) {"
        "return (args != null && args is! T);\n}");

    _writeln("\nstatic PageRoute _misTypedArgsRoute<T>(Object args) {"
        "return MaterialPageRoute(builder: (ctx) => Scaffold(body: Container("
        "color: Colors.redAccent,width: MediaQuery.of(ctx).size.width,"
        "padding: const EdgeInsets.symmetric(horizontal: 16.0),"
        "child: Column(mainAxisAlignment: MainAxisAlignment.center,children: <Widget>["
        "const Text('Arguments Mistype!',textAlign: TextAlign.center,style: const TextStyle(fontSize: 20),),"
        "const SizedBox(height: 8.0),"
        "Text('Expected (\${T.toString()}),  found (\${args.runtimeType})', textAlign: TextAlign.center,),"
        "const SizedBox(height: 16.0),"
        "OutlineButton.icon(label: Text('Back'), icon: Icon(Icons.arrow_back), onPressed: () => Navigator.of(ctx).pop(),)"
        "],),),),);}");
  }
}
