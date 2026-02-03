#if defined(SDL_PLATFORM_OHOS)

#include <cstdint>
#include <cerrno>
#include <cstdio>
#include <cstdlib>
#include <fstream>
#include <sys/stat.h>
#include <unistd.h>
#include <vector>
#include <string>

#include <napi/native_api.h>
#include <EGL/egl.h>
#include <SDL3/SDL_video.h>
#include <SDL3/SDL_hints.h>
#include <SDL3/SDL_log.h>

namespace love::ohos
{
	void setSandboxPath(const char *path);
	void setGameResourcePath(const char *path);
} // namespace love::ohos

extern "C" int love_run(int argc, char **argv);

namespace
{
	std::string g_sandbox_path;
	std::string g_game_resource_path;
	FILE *g_log = nullptr;

	static bool FileExists(const std::string &path)
	{
		std::ifstream f(path, std::ios::in | std::ios::binary);
		return f.good();
	}

	static bool WriteFile(const std::string &path, const std::string &data)
	{
		std::ofstream f(path, std::ios::out | std::ios::binary | std::ios::trunc);
		if (!f.good())
			return false;
		f.write(data.data(), static_cast<std::streamsize>(data.size()));
		return f.good();
	}

	static void EnsureDir(const std::string &path)
	{
		if (path.empty())
			return;
		int rc = ::mkdir(path.c_str(), 0755);
		if (rc == 0)
			return;
		if (errno == EEXIST)
			return;
	}

	static void SDLLogToFile(void *userdata, int /*category*/, SDL_LogPriority /*priority*/, const char *message)
	{
		FILE *f = static_cast<FILE *>(userdata);
		if (!f || !message)
			return;
		std::fprintf(f, "%s\n", message);
		std::fflush(f);
	}

	extern "C" int main()
	{
		love::ohos::setSandboxPath(g_sandbox_path.c_str());

		if (!g_sandbox_path.empty())
		{
			EnsureDir(g_sandbox_path);
			const std::string logpath = g_sandbox_path + "/love.log";
			g_log = std::fopen(logpath.c_str(), "w");
			if (g_log)
			{
				dup2(fileno(g_log), fileno(stdout));
				dup2(fileno(g_log), fileno(stderr));
				setvbuf(stdout, nullptr, _IONBF, 0);
				setvbuf(stderr, nullptr, _IONBF, 0);
				SDL_SetLogOutputFunction(SDLLogToFile, g_log);
				SDL_SetLogPriorities(SDL_LOG_PRIORITY_VERBOSE);
			}
			else
			{
				SDL_Log("fopen(%s) failed errno=%d", logpath.c_str(), errno);
			}
		}

		SDL_SetHint(SDL_HINT_EGL_LIBRARY, "libEGL.so");
		SDL_SetHint(SDL_HINT_OPENGL_LIBRARY, "libGLESv2.so");
		SDL_SetHint(SDL_HINT_OPENGL_ES_DRIVER, "libGLESv2.so");
		SDL_SetHint("LOVE_GRAPHICS_USE_OPENGLES", "1");
		SDL_SetHint(SDL_HINT_TOUCH_MOUSE_EVENTS, "0");
		SDL_SetHint(SDL_HINT_MOUSE_TOUCH_EVENTS, "0");

		using OH_Graphics_QueryGL_FUNC = EGLBoolean (*)(void);
		OH_Graphics_QueryGL_FUNC querygl =
			(OH_Graphics_QueryGL_FUNC)eglGetProcAddress("OH_Graphics_QueryGL");

		if (querygl != nullptr)
		{
			EGLBoolean useGL = querygl();
			SDL_Log("OH_Graphics_QueryGL exists, return=%d", (int)useGL);

			if (useGL)
			{
				SDL_SetHint("LOVE_GRAPHICS_USE_OPENGLES", "0");
				SDL_SetHint("LOVE_GRAPHICS_USE_GL3", "1");
			}
		}
		else
		{
			SDL_Log("OH_Graphics_QueryGL missing, fallback to GLES");
		}

		SDL_Log("SDL_HINT_OPENGL_LIBRARY=%s", SDL_GetHint(SDL_HINT_OPENGL_LIBRARY));
		SDL_Log("SDL_HINT_OPENGL_ES_DRIVER=%s", SDL_GetHint(SDL_HINT_OPENGL_ES_DRIVER));
		SDL_Log("LOVE_GRAPHICS_USE_OPENGLES=%s", SDL_GetHint("LOVE_GRAPHICS_USE_OPENGLES"));

		std::string resourceDir = g_game_resource_path;
		if (resourceDir.empty() && !g_sandbox_path.empty())
		{
			const std::string candidate = g_sandbox_path + "/game.love";
			if (FileExists(candidate))
				resourceDir = g_sandbox_path;
		}
		love::ohos::setGameResourcePath(resourceDir.c_str());
		SDL_Log("sandbox=%s", g_sandbox_path.c_str());
		SDL_Log("resourceDir=%s", resourceDir.c_str());
		if (!resourceDir.empty())
		{
			SDL_Log("resourceDir/game.love exists=%d", FileExists(resourceDir + "/game.love") ? 1 : 0);
		}

		std::vector<char *> argv;
		argv.push_back(const_cast<char *>("love"));
		argv.push_back(const_cast<char *>("--renderers"));
		argv.push_back(const_cast<char *>("opengl,vulkan"));
		if (!resourceDir.empty())
			argv.push_back(const_cast<char *>(resourceDir.c_str()));
		argv.push_back(nullptr);

		int rc = love_run(static_cast<int>(argv.size() - 1), argv.data());
		SDL_Log("love_run rc=%d", rc);
		if (g_log)
		{
			std::fclose(g_log);
			g_log = nullptr;
		}
		return rc;
	}

	napi_value Start(napi_env env, napi_callback_info /*info*/)
	{
		napi_value result = nullptr;
		napi_create_int32(env, 0, &result);
		return result;
	}

	napi_value SetPaths(napi_env env, napi_callback_info info)
	{
		size_t argc = 2;
		napi_value argv[2] = {nullptr, nullptr};
		napi_get_cb_info(env, info, &argc, argv, nullptr, nullptr);

		auto readString = [&](napi_value v) -> std::string
		{
			size_t len = 0;
			napi_get_value_string_utf8(env, v, nullptr, 0, &len);
			std::string s(len, '\0');
			if (len > 0)
			{
				size_t out = 0;
				napi_get_value_string_utf8(env, v, s.data(), len + 1, &out);
				s.resize(out);
			}
			return s;
		};

		if (argc >= 1 && argv[0])
			g_sandbox_path = readString(argv[0]);
		if (argc >= 2 && argv[1])
			g_game_resource_path = readString(argv[1]);

		napi_value result = nullptr;
		napi_create_int32(env, 0, &result);
		return result;
	}

	napi_value Init(napi_env env, napi_value exports)
	{
		napi_property_descriptor desc[] = {
			{"start", nullptr, Start, nullptr, nullptr, nullptr, napi_default, nullptr},
			{"setPaths", nullptr, SetPaths, nullptr, nullptr, nullptr, napi_default, nullptr},
		};
		napi_define_properties(env, exports, sizeof(desc) / sizeof(desc[0]), desc);

		return exports;
	}

	napi_module g_module = {
		.nm_version = 1,
		.nm_flags = 0,
		.nm_filename = nullptr,
		.nm_register_func = Init,
		.nm_modname = "entry",
		.nm_priv = nullptr,
		.reserved = {0},
	};
} // namespace

extern "C" __attribute__((constructor)) void RegisterModule()
{
	napi_module_register(&g_module);
}

#else

extern "C" void RegisterModule() {}

#endif
