#define WIN32_LEAN_AND_MEAN
#define DIRECTINPUT_VERSION 0x0800
#include <winsock2.h>
#include <windows.h>
#include <dinput.h>
#include <cstdio>
#include <cstdlib>
#include <cmath>
#include <vector>
#pragma comment(lib, "ws2_32.lib")
#pragma comment(lib, "dinput8.lib")
#pragma comment(lib, "dxguid.lib")
#pragma comment(lib, "user32.lib")
#pragma comment(lib, "ole32.lib")
struct Device { IDirectInputDevice8A* device; DIDEVICEINSTANCEA info; bool force; bool primary; };
static IDirectInput8A* input;
static std::vector<Device> devices;
static HWND window;
static HWND game_window;
static BOOL CALLBACK enumerate(const DIDEVICEINSTANCEA* info, void*) {
    IDirectInputDevice8A* d = nullptr;
    if (FAILED(input->CreateDevice(info->guidInstance, &d, nullptr))) return DIENUM_CONTINUE;
    DIDEVCAPS caps = {}; caps.dwSize = sizeof(caps); d->GetCapabilities(&caps);
    if (FAILED(d->SetDataFormat(&c_dfDIJoystick2)) || FAILED(d->SetCooperativeLevel(window, DISCL_BACKGROUND | DISCL_NONEXCLUSIVE))) {
        d->Release(); return DIENUM_CONTINUE;
    }
    DIPROPGUIDANDPATH path = {}; path.diph.dwSize = sizeof(path); path.diph.dwHeaderSize = sizeof(DIPROPHEADER); path.diph.dwHow = DIPH_DEVICE;
    d->GetProperty(DIPROP_GUIDANDPATH,&path.diph);
    bool primary = wcsstr(path.wszPath,L"col01") != nullptr || wcsstr(path.wszPath,L"COL01") != nullptr;
    d->Acquire(); devices.push_back({d, *info, (caps.dwFlags & DIDC_FORCEFEEDBACK) != 0, primary}); return DIENUM_CONTINUE;
}
static bool read(Device& d, DIJOYSTATE2& state) {
    d.device->Poll();
    if (SUCCEEDED(d.device->GetDeviceState(sizeof(state), &state))) return true;
    d.device->Acquire(); d.device->Poll();
    return SUCCEEDED(d.device->GetDeviceState(sizeof(state), &state));
}
struct Request { unsigned magic; float torque; unsigned active; };
struct Reply { unsigned magic, present, force; float axes[16]; unsigned buttons[8]; };
static_assert(sizeof(Request) == 12 && sizeof(Reply) == 108, "wire format");
int main(int argc, char** argv) {
    CoInitializeEx(nullptr, COINIT_MULTITHREADED);
    bool probe = argc > 1 && strcmp(argv[1], "--probe") == 0;
    game_window = argc > 2 && !probe ? (HWND)(uintptr_t)_strtoui64(argv[2], nullptr, 10) : nullptr;
    window = CreateWindowExA(0,"STATIC","Racing Sim wheel input",WS_POPUP,0,0,1,1,nullptr,nullptr,GetModuleHandle(nullptr),nullptr);
    if (FAILED(DirectInput8Create(GetModuleHandle(nullptr), DIRECTINPUT_VERSION, IID_IDirectInput8A, (void**)&input, nullptr))) return 1;
    input->EnumDevices(DI8DEVCLASS_GAMECTRL, enumerate, nullptr, DIEDFL_ATTACHEDONLY);
    if (argc == 1 || probe) {
      for (int sample = 0; sample < (probe ? 300 : 1); ++sample) {
        MSG message;
        while (PeekMessage(&message,nullptr,0,0,PM_REMOVE)) {TranslateMessage(&message); DispatchMessage(&message);}
        for (auto& d : devices) {
            DIJOYSTATE2 s = {}; bool ok = read(d,s);
            printf("%s vendor=%04x product=%04x force=%d primary=%d state=%d axes=%ld,%ld,%ld,%ld,%ld,%ld,%ld,%ld\n",
                d.info.tszProductName, LOWORD(d.info.guidProduct.Data1), HIWORD(d.info.guidProduct.Data1), d.force, d.primary, ok,
                s.lX,s.lY,s.lZ,s.lRx,s.lRy,s.lRz,s.rglSlider[0],s.rglSlider[1]);
            for (int b = 0; b < 128; ++b) if (s.rgbButtons[b] & 128) printf("button %s %d\n",d.info.tszProductName,b);
        }
        fflush(stdout);
        if (probe) Sleep(100);
      }
    } else {
        Device* wheel = nullptr; Device* pedals = nullptr;
        for (auto& d : devices) {
            unsigned vid = LOWORD(d.info.guidProduct.Data1), pid = HIWORD(d.info.guidProduct.Data1);
            if (vid == 0x0eb7 && pid == 0x0020 && (!wheel || (!wheel->primary && d.primary))) wheel = &d;
            if (vid == 0x346e && pid == 0x0008) pedals = &d;
        }
        if (!wheel && !pedals) return 2;
        for (auto& d : devices) if (&d != wheel && &d != pedals) d.device->Unacquire();
        IDirectInputEffect* effect = nullptr;
        bool reported = false;
        HRESULT effect_error = S_OK;
        DIPROPDWORD original_autocenter = {};
        original_autocenter.diph.dwSize = sizeof(original_autocenter);
        original_autocenter.diph.dwHeaderSize = sizeof(DIPROPHEADER);
        original_autocenter.diph.dwHow = DIPH_DEVICE;
        bool restore_autocenter = false;
        if (wheel && wheel->force) {
            wheel->device->Unacquire();
            restore_autocenter = SUCCEEDED(wheel->device->GetProperty(DIPROP_AUTOCENTER,&original_autocenter.diph));
            HRESULT coop = wheel->device->SetCooperativeLevel(window, DISCL_BACKGROUND | DISCL_EXCLUSIVE);
            if (FAILED(coop)) fprintf(stderr,"wheel cooperative mode failed: %08lx\n",coop);
            DIPROPDWORD autocenter = {}; autocenter.diph.dwSize = sizeof(autocenter); autocenter.diph.dwHeaderSize = sizeof(DIPROPHEADER);
            autocenter.diph.dwHow = DIPH_DEVICE; autocenter.dwData = DIPROPAUTOCENTER_OFF;
            wheel->device->SetProperty(DIPROP_AUTOCENTER,&autocenter.diph);
        }
        WSADATA wsa; WSAStartup(MAKEWORD(2,2), &wsa);
        SOCKET sock = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP);
        sockaddr_in local = {}; local.sin_family = AF_INET; local.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
        if (bind(sock,(sockaddr*)&local,sizeof(local)) != 0) return 3;
        sockaddr_in game = {}; game.sin_family = AF_INET; game.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
        game.sin_port = htons((unsigned short)atoi(argv[1]));
        DWORD timeout = 100; setsockopt(sock,SOL_SOCKET,SO_RCVTIMEO,(char*)&timeout,sizeof(timeout));
        HANDLE parent = argc > 3 ? OpenProcess(SYNCHRONIZE,FALSE,(DWORD)atoi(argv[3])) : nullptr;
        unsigned long long last = GetTickCount64();
        Request request = {}; request.magic = 0x52494739;
        // The driver initially returns placeholder midpoints until its first USB report.
        for (int i = 0; i < 10; ++i) {
            for (Device* d : {wheel,pedals}) if (d) { DIJOYSTATE2 s = {}; read(*d,s); }
            Sleep(10);
        }
        while ((!parent || WaitForSingleObject(parent,0) == WAIT_TIMEOUT) && GetTickCount64() - last < 3000) {
            MSG message;
            while (PeekMessage(&message,nullptr,0,0,PM_REMOVE)) {TranslateMessage(&message); DispatchMessage(&message);}
            Reply reply = {}; reply.magic = 0x52494739;
            Device* selected[] = {wheel,pedals};
            for (int n = 0; n < 2; ++n) if (selected[n]) {
                DIJOYSTATE2 s = {};
                if (read(*selected[n],s)) {
                    reply.present |= 1 << n;
                    LONG values[] = {s.lX,s.lY,s.lZ,s.lRx,s.lRy,s.lRz,s.rglSlider[0],s.rglSlider[1]};
                    for (int a = 0; a < 8; ++a) reply.axes[n*8+a] = values[a] / 65535.0f;
                    for (int b = 0; b < 128; ++b) if (s.rgbButtons[b] & 128) reply.buttons[n*4+b/32] |= 1u << (b%32);
                }
            }
            reply.force = effect ? 1 : (DWORD)effect_error;
            sendto(sock,(char*)&reply,sizeof(reply),0,(sockaddr*)&game,sizeof(game));
            sockaddr_in sender = {}; int size = sizeof(sender);
            int got = recvfrom(sock,(char*)&request,sizeof(request),0,(sockaddr*)&sender,&size);
            bool valid = got == sizeof(request) && request.magic == 0x52494739 && sender.sin_addr.s_addr == game.sin_addr.s_addr && sender.sin_port == game.sin_port;
            if (valid) last = GetTickCount64();
            if (valid && request.active == 2) break;
            bool active = valid && request.active == 1 && std::isfinite(request.torque) && GetForegroundWindow() == game_window && (reply.present & 1);
            if (wheel && active) {
                DWORD axis = DIJOFS_X; LONG direction = 10000;
                DICONSTANTFORCE force = {(LONG)(max(-1.0f,min(1.0f,request.torque))*10000)};
                DIEFFECT desc = {}; desc.dwSize = sizeof(desc); desc.dwFlags = DIEFF_CARTESIAN | DIEFF_OBJECTOFFSETS;
                desc.dwDuration = 100000; desc.dwGain = DI_FFNOMINALMAX; desc.dwTriggerButton = DIEB_NOTRIGGER;
                desc.cAxes = 1; desc.rgdwAxes = &axis; desc.rglDirection = &direction;
                desc.cbTypeSpecificParams = sizeof(force); desc.lpvTypeSpecificParams = &force;
                if (!effect && wheel->force) {
                    HRESULT result = wheel->device->CreateEffect(GUID_ConstantForce,&desc,&effect,nullptr);
                    effect_error = result;
                    if (!reported) {
                        fprintf(stderr,"CSL DD constant force: %08lx\n",result);
                        reported = true;
                    }
                }
                if (effect) {
                    HRESULT result = effect->SetParameters(&desc,DIEP_TYPESPECIFICPARAMS | DIEP_DURATION | DIEP_START);
                    if (FAILED(result)) {effect_error = result; effect->Stop(); effect->Release(); effect = nullptr;}
                }
            } else if (effect) effect->Stop();
        }
        if (effect) {effect->Stop(); effect->Release();}
        if (wheel) wheel->device->SendForceFeedbackCommand(DISFFC_STOPALL);
        if (wheel && restore_autocenter) {
            wheel->device->Unacquire();
            wheel->device->SetProperty(DIPROP_AUTOCENTER,&original_autocenter.diph);
        }
        if (parent) CloseHandle(parent);
        closesocket(sock); WSACleanup();
    }
    for (auto& d : devices) {d.device->Unacquire(); d.device->Release();}
    input->Release(); DestroyWindow(window); CoUninitialize(); return 0;
}
